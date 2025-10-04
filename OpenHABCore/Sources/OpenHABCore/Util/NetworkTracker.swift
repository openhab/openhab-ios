// Copyright (c) 2010-2025 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

@preconcurrency import Combine
import Foundation
import Kingfisher
import Network
import OpenAPIRuntime
import os.log

// TODO: these strings should reference Localizable keys
public enum NetworkStatus: String, Sendable {
    case connecting = "Connecting"
    case connected = "Connected"
    case notConnected = "Not Connected"
    case someConnected = "Some Connected"
    case allConnected = "All Connected"
}

public struct ConnectionInfo: Equatable, Sendable {
    public let configuration: ConnectionConfiguration
    public let version: Int

    // Explicit public memberwise initializer
    public init(configuration: ConnectionConfiguration, version: Int) {
        self.configuration = configuration
        self.version = version
    }
}

public enum NetworkTrackerError: Error, CustomDebugStringConvertible, Sendable {
    case serviceUnavailable
    case invalidServerVersion
    case failedConnection(String)
    case noActiveConnection

    public var debugDescription: String {
        switch self {
        case .serviceUnavailable: "Could not create OpenAPIService instance"
        case .invalidServerVersion: "Invalid server version"
        case let .failedConnection(url): "Failed to connect to \(url)"
        case .noActiveConnection: "No active server found"
        }
    }
}

// Prevent race conditions.
// Ensure thread-safe dictionary access.
// Avoid memory corruption errors like unrecognized selector.
public actor ConnectionPool {
    private var services: [ConnectionConfiguration: any OpenAPIServiceProtocol] = [:]
    private let serviceFactory: @Sendable (ConnectionConfiguration) throws -> any OpenAPIServiceProtocol

    // Initializer allowing the injection of mocked OpenAPIServiceProtocol
    init(serviceFactory: @escaping @Sendable (ConnectionConfiguration) throws -> any OpenAPIServiceProtocol = {
        try OpenAPIService(connectionConfiguration: $0, serviceConfiguration: .shortTerm)
    }) {
        self.serviceFactory = serviceFactory
    }

    @discardableResult
    func getOrCreateService(for configuration: ConnectionConfiguration) async throws -> any OpenAPIServiceProtocol {
        if let existing = services[configuration] {
            return existing
        }
        let newService = try serviceFactory(configuration)
        services[configuration] = newService
        return newService
    }
}

// Ensures a thread safe access to failureCounts dictionary
public actor ConnectionFailureTracker {
    private var failureCounts: [ConnectionConfiguration: Int] = [:]
    private let maxFailures = 3

    func shouldAttempt(_ config: ConnectionConfiguration) -> Bool {
        (failureCounts[config] ?? 0) < maxFailures
    }

    func recordFailure(_ config: ConnectionConfiguration) {
        failureCounts[config, default: 0] += 1
    }

    func reset(_ config: ConnectionConfiguration) {
        failureCounts[config] = 0
    }

    func resetAll() {
        failureCounts.removeAll()
    }

    func maxFailureCount() -> Int {
        failureCounts.values.max() ?? 0
    }
}

@MainActor
public class MainActorNetworkTracker: ObservableObject {
    public static let shared = MainActorNetworkTracker()
    @Published public var activeConnection: ConnectionInfo?
    @Published public var status: NetworkStatus = .connecting

    public init(tracker: NetworkTracker = NetworkTracker.shared) {
        Task {
            for await connection in await tracker.activeConnectionStream() {
                activeConnection = connection
                status = await NetworkTracker.shared.status
            }
        }
        Task {
            for await trackerStatus in await tracker.statusStream() {
                activeConnection = await NetworkTracker.shared.activeConnection
                status = trackerStatus
            }
        }
    }
}

public actor CertificateManagers {
    @MainActor public static let clientCertificateManager = ClientCertificateManager()
    @MainActor public static let serverCertificateManager = ServerCertificateManager()
}

public actor NetworkTracker {
    public static let shared = NetworkTracker()

    public static let networkTimeout: TimeInterval = 10
    public static let slowConnectionTimeout: TimeInterval = 1

    @Published public private(set) var activeConnection: ConnectionInfo?

    @Published public private(set) var status: NetworkStatus = .connecting

    private var pathMonitor: any NWPathMonitoring
    private var connectionPool: ConnectionPool
    private var connectionConfigurations: [ConnectionConfiguration] = []
    private var retryTask: Task<Void, Never>?

    private var failureTracker: ConnectionFailureTracker

    private let logger = Logger(subsystem: "org.openhab.core", category: "NetworkTracker")

    // MARK: - Injectable initializer for testing

    init(monitor: any NWPathMonitoring = RealPathMonitor(),
         connectionPool: ConnectionPool = ConnectionPool(),
         failureTracker: ConnectionFailureTracker = ConnectionFailureTracker()) {
        pathMonitor = monitor
        self.connectionPool = connectionPool
        self.failureTracker = failureTracker
    }

    public func startTracking(connectionConfigurations: [ConnectionConfiguration]) async {
        logger.info("Start Network Tracking for \(connectionConfigurations.map { "url: \($0.url), user: \($0.username)" })")
        self.connectionConfigurations = connectionConfigurations

        Task(priority: .utility) { [weak self] in
            await self?.pathMonitor.startMonitoring { isConnected in
                await self?.handleNetworkChange(isConnected: isConnected)
            }
        }

        for configuration in connectionConfigurations {
            do {
                _ = try await connectionPool.getOrCreateService(for: configuration)
            } catch {
                logger.error("Failed to create service for config: \(configuration.url, privacy: .public) — \(error.localizedDescription)")
                // Optionally: show a UI popup or skip to next config
            }
        }

        await setActiveConnection(nil)
        await attemptConnection()
    }

    public func stopTracking() async {
        retryTask?.cancel()
        retryTask = nil
        pathMonitor.cancel()
        await setActiveConnection(nil)
    }

    public func waitForActiveConnection(timeout: TimeInterval = NetworkTracker.networkTimeout) async -> ConnectionInfo? {
        logger.info("NetworkConnection: waitForActiveConnection")
        // If we already have an active connection, return it immediately
        if let existing = activeConnection { return existing }
        // Utilize for await to listen for changes in $activeConnection
        // $activeConnection.values is an AsyncSequence, allowing you to iterate over its values asynchronously.
        // Wait until a non-nil value is received
        let logger = logger
        return await withTimeout(timeout: timeout) {
            logger.info("NetworkConnection: Start waiting for active connection connection with timeout")
            if let current = await self.activeConnection { return current }
            for await connection in await self.$activeConnection.values {
                if let connection {
                    logger.info("NetworkConnection: active connection received")
                    return connection
                }
            }
            return nil
        }
    }

    public func restartTracking() {
        logger.debug("NetworkConnection: restartTracking")
        Task {
            await setActiveConnection(nil)
            await attemptConnection()
        }
    }

    // This gets called periodically when we have an active connection to make sure it's still the best choice
    private func checkActiveConnection() async {
        guard let activeConnection else {
            // No active connection, proceed with the normal connection attempt
            logger.info("No active connection, attempting to reconnect...")
            await attemptConnection()
            return
        }

        // Check if the active connection is reachable
        do {
            try await connectionPool
                .getOrCreateService(for: activeConnection.configuration)
                .getRoot()
            logger.debug("Active connection is reachable: \(activeConnection.configuration.url)")
        } catch {
            logger.error("Active connection failed: \(activeConnection.configuration.url) - \(error.localizedDescription)")
            await setActiveConnection(nil)
            await attemptConnection()
        }
    }

    private func attemptConnection() async {
        guard activeConnection == nil else {
            // with an active connection there is no need to attempt a reconnection
            return
        }

        guard !connectionConfigurations.isEmpty else {
            logger.error("No connection configurations available.")
            await updateStatus(.notConnected)
            await setActiveConnection(nil)
            return
        }

        logger.debug("Checking available connections...")
        if let bestConnection = await findBestConnection() {
            logger.info("Best connection url: \(bestConnection.configuration.url) user: \(bestConnection.configuration.username)")
            await setActiveConnection(bestConnection)
        } else {
            logger.info("No connection succeeded")
            await updateStatus(.notConnected)
            await setActiveConnection(nil)
        }
    }

    private func findBestConnection() async -> ConnectionInfo? {
        let sortedConfigs = connectionConfigurations.sorted { $0.priority < $1.priority }
        var bestConnection: ConnectionInfo?
        var connectedCount = 0
        let logger = logger

        await withTaskGroup(of: ConnectionInfo?.self) { group in
            for config in sortedConfigs {
                group.addTask {
                    await self.testConnection(configuration: config)
                }
            }

            var timestampWhenFirstConnectionFound = Date.distantFuture

            for await connectionInfo in group {
                let timePassedSinceFirstConnectionFound = timestampWhenFirstConnectionFound.distance(to: Date())
                if connectedCount >= 1, timePassedSinceFirstConnectionFound >= NetworkTracker.slowConnectionTimeout {
                    // This will be triggered by the task added when first connection has been found
                    group.cancelAll()
                    break
                }

                guard let connectionInfo else { continue }

                connectedCount += 1

                if connectionInfo.configuration.priority == 0 {
                    bestConnection = connectionInfo
                    group.cancelAll() // Stop further tasks if we found the highest-priority connection
                    break
                }

                guard let currentBestConnection = bestConnection else {
                    bestConnection = connectionInfo
                    timestampWhenFirstConnectionFound = Date()
                    // give the others a short time to be found, otherwise cancel early
                    // do this by adding a task that runs for at most slowConnectionTimeout seconds, and check whether those have passed
                    group.addTask {
                        try? await Task.sleep(for: .seconds(NetworkTracker.slowConnectionTimeout))
                        logger.info("NetworkConnection: Prefer fastest over higher prioritized one, cancel search")
                        return nil
                    }
                    continue
                }

                if connectionInfo.configuration.priority < currentBestConnection.configuration.priority {
                    bestConnection = connectionInfo
                    group.cancelAll()
                }
            }
        }

        // Update status based on the number of successful connections
        if connectedCount == 0 {
            await updateStatus(.notConnected)
        } else if connectedCount == 1 {
            await updateStatus(.someConnected)
        } else if bestConnection != nil {
            await updateStatus(.allConnected)
        }
        return bestConnection
    }

    private func withTimeout<T: Sendable>(timeout: TimeInterval, operation: @Sendable @escaping () async -> T?) async -> T? {
        let logger = logger
        return await withTaskGroup(of: T?.self) { group in
            // Start the operation
            group.addTask {
                await operation()
            }

            // Start the timeout countdown
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                logger.info("NetworkConnection: Timeout reached")
                return nil
            }

            // Return the first task that finishes (operation or timeout)
            return await group.first { $0 != nil } ?? nil
        }
    }

    private func testConnection(configuration: ConnectionConfiguration) async -> ConnectionInfo? {
        guard URL(string: configuration.url) != nil else { return nil }

        let shouldTry = await failureTracker.shouldAttempt(configuration)
        if !shouldTry {
            logger.info("Skipping \(configuration.url) due to repeated failures.")
            return nil
        }

        do {
            logger.info("testConnection for url: \(configuration.url) user: \(configuration.username)")
            let connection = try await connectionPool.getOrCreateService(for: configuration)
            let version = try await connection.getRootVersion()
            let connectionInfo = ConnectionInfo(configuration: configuration, version: version)

            await failureTracker.reset(configuration) // Reset on success
            logger.info("testConnection successful for \(configuration.url)")
            return connectionInfo
        } catch NetworkTrackerError.invalidServerVersion {
            logger.info("testConnection error - Invalid server version from \(configuration.url)")
            await failureTracker.recordFailure(configuration)

            return nil
        } catch let error as OpenAPIServiceError {
            switch error {
            case let .undocumented(statusCode, payload):
                logger.info("Undocumented status code: \(statusCode), payload: \(String(describing: payload))")
                return nil
            default:
                return nil
            }
        } catch let openAPIError as OpenAPIRuntime.ClientError {
            logger.info("NetworkConnection: testConnection error - OpenAPIRuntime.RuntimeError encountered for \(configuration.url)")
            logger.debug("OpenAPIRuntime.RuntimeError is \(openAPIError)")
            return nil
        } catch {
            logger.info("testConnection error - Failed to connect to \(configuration.url) \(error.localizedDescription)")
            await failureTracker.recordFailure(configuration)
            return nil
        }
    }

    private func startRetryTask(_ initialRetryInterval: UInt64) {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            guard let self else { return }
            let backoffMultiplier = await UInt64(failureTracker.maxFailureCount())
            let safeBackoff = min(backoffMultiplier, 10) // 2^10 = 1024
            let delay = min(initialRetryInterval * (1 << safeBackoff), 300)
            logger.info("Retrying in \(delay) seconds based on failure count.")
            try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
            await attemptConnection()
        }
    }

    private func handleNetworkChange(isConnected: Bool) async {
        if isConnected {
            logger.info("Network status: Connected")
            await checkActiveConnection()
        } else {
            logger.info("Network status: Disconnected")
            await setActiveConnection(nil)
            await updateStatus(.notConnected)
            startRetryTask(10)
        }
    }

    private func setActiveConnection(_ connection: ConnectionInfo?) async {
        guard activeConnection != connection else { return }

        activeConnection = connection
        status = connection == nil ? .notConnected : .connected
        if let connection {
            // TODO: suspicious call to "shared" instance with specific connection
            KingfisherManager.shared.defaultOptions = [.requestModifier(OpenHABAccessTokenAdapter(connectionConfiguration: connection.configuration))]
        } else {
            startRetryTask(30)
        }
    }

    private func updateStatus(_ newStatus: NetworkStatus) async {
        guard status != newStatus else { return } // Prevent redundant updates
        status = newStatus
        logger.info("Network status updated: \(newStatus.rawValue)")
    }

    public func resetFailures() {
        Task {
            await failureTracker.resetAll()
        }
    }
}

public extension NetworkTracker {
    private func service() async throws -> any OpenAPIServiceProtocol {
        guard let connection = await waitForActiveConnection()?.configuration else {
            throw NetworkTrackerError.noActiveConnection
        }
        guard let service = try? await connectionPool.getOrCreateService(for: connection) else {
            throw NetworkTrackerError.serviceUnavailable
        }
        return service
    }

    func send(to item: OpenHABItem, command: String) async throws {
        try await send(to: item.name, command: command)
    }

    func send(to item: String, command: String) async throws {
        try await service().sendItemCommand(itemname: item, command: command)
    }

    func updateState(item: OpenHABItem, state: String) async throws {
        try await service().updateItemState(itemname: item.name, with: state)
    }

    func getStaticItems() async throws -> [OpenHABItem] {
        let items = try await service().getItems(query: Operations.getItems.Input.Query(staticDataOnly: true))
        return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func getItemByName(id: String) async throws -> OpenHABItem? {
        try await service().getItemByName(id: id)
    }

    func pollDataForPage(sitemapname: String, pageId: String = "", longPolling: Bool = false) async throws -> OpenHABPage? {
        try await service().pollDataForPage(sitemapname: sitemapname, pageId: pageId, longPolling: longPolling)
    }

    func runNow(ruleUID: String, payload: [String: String]) async throws {
        try await service().runNow(ruleUID: ruleUID, payload: payload)
    }
}

public extension NetworkTracker {
    func activeConnectionStream() -> AsyncStream<ConnectionInfo?> {
        AsyncStream { continuation in
            let cancellable = self.$activeConnection
                .sink { continuation.yield($0) }

            continuation.onTermination = { [cancellable] _ in cancellable.cancel() }
        }
    }

    func statusStream() -> AsyncStream<NetworkStatus> {
        AsyncStream { continuation in
            let cancellable = self.$status
                .sink { continuation.yield($0) }

            continuation.onTermination = { [cancellable] _ in cancellable.cancel() }
        }
    }
}

#if DEBUG
public extension NetworkTracker {
    func setMockConnection(_ connection: ConnectionInfo) {
        activeConnection = connection
    }
}
#endif
