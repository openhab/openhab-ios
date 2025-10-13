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
    case stopped = "Stopped"
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
    case noActiveConnection

    public var debugDescription: String {
        switch self {
        case .serviceUnavailable: "Could not create OpenAPIService instance"
        case .invalidServerVersion: "Invalid server version"
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

    func setConnections(_ connections: [ConnectionConfiguration]) {
        failureCounts = failureCounts.filter { connections.contains($0.key) }

        for key in connections where failureCounts[key] == nil {
            failureCounts[key] = 0
        }
    }

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
            }
        }
        Task {
            for await trackerStatus in await tracker.statusStream() {
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

    @Published public private(set) var status: NetworkStatus = .stopped

    private var pathMonitor: any NWPathMonitoring
    private var connectionPool: ConnectionPool
    private var connectionConfigurations: [ConnectionConfiguration] = []

    private var retryTask: Task<Void, Never>?

    private var failureTracker: ConnectionFailureTracker

    private var networkTimeout = NetworkTracker.networkTimeout

    private let logger = Logger(subsystem: "org.openhab.core", category: "NetworkTracker")

    // MARK: - Injectable initializer for testing

    public init(monitor: (any NWPathMonitoring)? = nil,
                connectionPool: ConnectionPool? = nil,
                failureTracker: ConnectionFailureTracker? = nil,
                timeout: TimeInterval = NetworkTracker.networkTimeout) {
        pathMonitor = monitor ?? RealPathMonitor()
        self.connectionPool = connectionPool ?? ConnectionPool()
        self.failureTracker = failureTracker ?? ConnectionFailureTracker()
        networkTimeout = timeout
    }

    /// Creates a task to start the tracking and returns immediately
    public func startTracking(connectionConfigurations: [ConnectionConfiguration]) async {
        logger.info("Start Network Tracking for \(connectionConfigurations.map { "url: \($0.url), user: \($0.username)" })")

        await failureTracker.setConnections(connectionConfigurations)
        self.connectionConfigurations = connectionConfigurations

        setActiveConnection(nil)
        updateStatus(.connecting)

        Task(priority: .utility) { [weak self] in
            await self?.pathMonitor.startMonitoring { isConnected in
                await self?.handleNetworkChange(isConnected: isConnected)
            }
        }

        Task(priority: .userInitiated) {
            for configuration in connectionConfigurations {
                do {
                    _ = try await connectionPool.getOrCreateService(for: configuration)
                } catch {
                    logger.error("Failed to create service for config: \(configuration.url, privacy: .public) — \(error.localizedDescription)")
                    // Optionally: show a UI popup or skip to next config
                }
            }
            await attemptConnection()
        }
    }

    public func stopTracking() async {
        retryTask?.cancel()
        retryTask = nil
        pathMonitor.cancel()
        setActiveConnection(nil)
        await failureTracker.resetAll()
        connectionConfigurations = []
        updateStatus(.stopped)
    }

    /// This function will pause execution until either an active connection was found or the timeout has been reached
    public func waitForActiveConnection() async -> ConnectionInfo? {
        guard status != .stopped else {
            logger.info("No connection from stopped network tracker possible")
            return nil
        }

        logger.info("NetworkConnection: waitForActiveConnection")
        // Utilize for await to listen for changes in $activeConnection
        // $activeConnection.values is an AsyncSequence, allowing you to iterate over its values asynchronously.
        // Wait until a non-nil value is received
        let logger = logger
        return try? await withTimeout(timeout: networkTimeout) { [self] in
            logger.info("NetworkConnection: Start waiting for active connection connection with timeout")
            let activeConnections = await $activeConnection.values
            if await status == .connected {
                // return existing conneciton
                if let current = await activeConnection { return current }
            }
            for await connection in activeConnections {
                if let connection {
                    logger.info("NetworkConnection: active connection received")
                    return connection
                }
            }
            return nil
        }
    }

    // like startTracking but with the already configured connections
    public func restartTracking() async {
        logger.debug("NetworkConnection: restartTracking")
        await startTracking(connectionConfigurations: connectionConfigurations)
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
            setActiveConnection(nil)
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
            setActiveConnection(nil)
            await stopTracking()
            return
        }

        logger.debug("Checking available connections...")
        if let bestConnection = await findBestConnection() {
            logger.info("Best connection url: \(bestConnection.configuration.url) user: \(bestConnection.configuration.username)")
            setActiveConnection(bestConnection)
        } else {
            logger.info("No connection succeeded")
            setActiveConnection(nil)
        }
    }

    /// Search for available connections among connectionConfigurations
    /// When the first one was found, we wait a small grace period if there is a preferred one that also works
    private func findBestConnection() async -> ConnectionInfo? {
        let sortedConfigs = connectionConfigurations.sorted { $0.priority < $1.priority }
        var connectedCount = 0
        let logger = logger

        let bestConnection = await withTaskGroup(of: ConnectionInfo?.self, returning: ConnectionInfo?.self) { group in
            for config in sortedConfigs {
                group.addTask {
                    try? await self.withTimeout(timeout: self.networkTimeout) {
                        let connection = await self.testConnection(configuration: config)
                        return connection
                    }
                }
            }

            var currentBestConnection: ConnectionInfo?
            var timestampWhenFirstConnectionFound = Date.distantFuture

            for await connectionInfo in group {
                let timePassedSinceFirstConnectionFound = timestampWhenFirstConnectionFound.distance(to: Date())
                if connectedCount >= 1, timePassedSinceFirstConnectionFound >= NetworkTracker.slowConnectionTimeout {
                    logger.info("Cancelling further connection tests, a connection has been found and timeout was reached")
                    // This will be triggered by the task added when first connection has been found
                    group.cancelAll()
                    return currentBestConnection
                }

                guard let connectionInfo else { continue }

                connectedCount += 1

                if connectionInfo.configuration.priority == 0 {
                    logger.info("Most prioritized connection with url: \(connectionInfo.configuration.url) and user: \(connectionInfo.configuration.username) tested successfully")
                    // Stop further tasks if we found the highest-priority connection and return it
                    group.cancelAll()
                    return connectionInfo
                }

                if let bestConnection = currentBestConnection, connectionInfo.configuration.priority < bestConnection.configuration.priority {
                    currentBestConnection = connectionInfo
                } else if currentBestConnection == nil {
                    currentBestConnection = connectionInfo
                }

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
            return currentBestConnection
        }
        return bestConnection
    }

    /// tests connectivity for a given connection, but at most until timeout
    private func testConnection(configuration: ConnectionConfiguration) async -> ConnectionInfo? {
        guard URL(string: configuration.url) != nil else { return nil }

        let shouldTry = await failureTracker.shouldAttempt(configuration)
        if !shouldTry {
            logger.info("Skipping \(configuration.url) due to repeated failures.")
            return nil
        }

        do {
            return try await withTimeout(timeout: networkTimeout) { [self] in
                logger.info("testConnection for url: \(configuration.url) user: \(configuration.username)")
                let connection = try await connectionPool.getOrCreateService(for: configuration)
                let version = try await connection.getRootVersion()
                let connectionInfo = ConnectionInfo(configuration: configuration, version: version)

                await failureTracker.reset(configuration) // Reset on success
                logger.info("testConnection successful for \(configuration.url)")
                return connectionInfo
            }
        } catch NetworkTrackerError.invalidServerVersion {
            logger.info("testConnection error - Invalid server version from \(configuration.url)")
            await failureTracker.recordFailure(configuration)
        } catch let error as OpenAPIServiceError {
            switch error {
            case let .undocumented(statusCode, payload):
                logger.info("Undocumented status code: \(statusCode), payload: \(String(describing: payload))")
            default: break
            }
        } catch let openAPIError as OpenAPIRuntime.ClientError {
            logger.info("NetworkConnection: testConnection error - OpenAPIRuntime.RuntimeError encountered for \(configuration.url)")
            logger.debug("OpenAPIRuntime.RuntimeError is \(openAPIError)")
        } catch {
            logger.info("testConnection error - Failed to connect to \(configuration.url) \(error.localizedDescription)")
            await failureTracker.recordFailure(configuration)
        }

        return nil
    }

    /// attempt to connect with repeatedly longer intervals
    private func startRetryTask(_ initialRetryInterval: UInt64) {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            guard let self else { return }
            let failureCount = await failureTracker.maxFailureCount()
            let backoffMultiplier = UInt64(failureCount)
            let safeBackoff = min(backoffMultiplier, 10) // 2^10 = 1024
            let delay = min(initialRetryInterval * (1 << safeBackoff), 300)
            logger.info("Retrying connection in \(delay) seconds based on failure count of \(failureCount).")
            try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
            await attemptConnection()
        }
    }

    /// keep trying to connect when network is not connected, otherwise check if active connection is actually available
    private func handleNetworkChange(isConnected: Bool) async {
        if isConnected {
            logger.info("Network status: Connected")
            await checkActiveConnection()
        } else {
            logger.info("Network status: Disconnected")
            setActiveConnection(nil)
            updateStatus(.connecting)
            startRetryTask(10)
        }
    }

    private func setActiveConnection(_ connection: ConnectionInfo?) {
        guard activeConnection != connection else { return }

        activeConnection = connection

        if let connection {
            updateStatus(.connected)
            // TODO: suspicious call to "shared" instance with specific connection
            KingfisherManager.shared.defaultOptions = [.requestModifier(OpenHABAccessTokenAdapter(connectionConfiguration: connection.configuration))]
        } else {
            startRetryTask(30)
        }
    }

    private func updateStatus(_ newStatus: NetworkStatus) {
        guard status != newStatus else { return } // Prevent redundant updates
        status = newStatus
        logger.info("Network status updated: \(newStatus.rawValue)")
    }

    private func withTimeout<T: Sendable>(timeout: TimeInterval, operation: @Sendable @escaping () async throws -> T?) async throws -> T? {
        let logger = logger
        return try await withThrowingTaskGroup(of: T?.self) { group in
            // Start the operation
            group.addTask {
                try await operation()
            }

            // Start the timeout countdown
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                logger.info("NetworkConnection: Timeout reached")
                return nil
            }

            // Return the first task that finishes (operation or timeout)
            if let firstResult = try await group.next() {
                group.cancelAll()
                return firstResult
            }

            return nil
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
