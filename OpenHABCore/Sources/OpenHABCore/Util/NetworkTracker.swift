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
public enum NetworkStatus: String {
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
    case invalidServerVersion
    case failedConnection(String)
    case noActiveConnection

    public var debugDescription: String {
        switch self {
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
    private var services: [ConnectionConfiguration: OpenAPIServiceProtocol] = [:]
    private let serviceFactory: (ConnectionConfiguration) throws -> OpenAPIServiceProtocol

    // Initializer allowing the injection of mocked OpenAPIServiceProtocol
    init(serviceFactory: @escaping (ConnectionConfiguration) throws -> OpenAPIServiceProtocol = {
        try OpenAPIService(connectionConfiguration: $0, serviceConfiguration: .shortTerm)
    }) {
        self.serviceFactory = serviceFactory
    }

    @discardableResult
    func getOrCreateService(for configuration: ConnectionConfiguration) async throws -> OpenAPIServiceProtocol {
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

public protocol NetworkTracking: ObservableObject {
    var activeConnection: ConnectionInfo? { get }
}

public final class NetworkTracker: ObservableObject {
    public static let shared = NetworkTracker()

    // @MainActor
    @Published public private(set) var activeConnection: ConnectionInfo?
    // @MainActor
    @Published public private(set) var status: NetworkStatus = .connecting

    private var pathMonitor: NWPathMonitoring
    private var connectionPool: ConnectionPool
    private var connectionConfigurations: [ConnectionConfiguration] = []
    private var retryTask: Task<Void, Never>?
    private let disconnectedRetryInterval: UInt64 = 30 // / amount of time we scan when not connected

    private var failureTracker: ConnectionFailureTracker

    // TODO: remove
    public var clientCertificateManager = ClientCertificateManager()
    public var serverCertificateManager = ServerCertificateManager()
    public private(set) var httpClient: HTTPClient?

    private let logger = Logger(subsystem: "org.openhab.core", category: "NetworkTracker")

    // MARK: - Injectable initializer for testing

    init(monitor: NWPathMonitoring = RealPathMonitor(),
         connectionPool: ConnectionPool = ConnectionPool(),
         failureTracker: ConnectionFailureTracker = ConnectionFailureTracker()) {
        pathMonitor = monitor
        self.connectionPool = connectionPool
        self.failureTracker = failureTracker
    }

    public func startTracking(connectionConfigurations: [ConnectionConfiguration]) async {
        logger.info("Start Network Tracking")
        self.connectionConfigurations = connectionConfigurations

        Task.detached(priority: .utility) { [weak self] in
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

    public func waitForActiveConnection(timeout: TimeInterval = 10) async -> ConnectionInfo? {
        logger.info("NetworkConnection: waitForActiveConnection")
        // Utilize for await to listen for changes in $activeConnection
        // $activeConnection.values is an AsyncSequence, allowing you to iterate over its values asynchronously.
        // Wait until a non-nil value is received
        for await connection in $activeConnection.values {
            if let connection {
                return connection
            }
        }
        return nil
    }

    public func restartTracking() {
        Task { await attemptConnection() }
    }

    // This gets called periodically when we have an active connection to make sure it's still the best choice
    private func checkActiveConnection() async {
        guard let activeConnection else {
            // No active connection, proceed with the normal connection attempt
            os_log("No active connection, attempting to reconnect...", log: OSLog.default, type: .info)
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
            await attemptConnection()
        }
    }

    private func attemptConnection() async {
        guard !connectionConfigurations.isEmpty else {
            logger.error("No connection configurations available.")
            await updateStatus(.notConnected)
            await setActiveConnection(nil)
            return
        }

        logger.debug("Checking available connections...")
        if let bestConnection = await findBestConnection() {
            await setActiveConnection(bestConnection)
        } else {
            await updateStatus(.notConnected)
            await setActiveConnection(nil)
        }
//        let bestConnection = await findBestConnection()
//        await setActiveConnection(bestConnection)
    }

    private func findBestConnection() async -> ConnectionInfo? {
        let sortedConfigs = connectionConfigurations.sorted { $0.priority < $1.priority }
        var bestConnection: ConnectionInfo?
        var connectedCount = 0

        await withTaskGroup(of: ConnectionInfo?.self) { group in
            for config in sortedConfigs {
                group.addTask {
                    await self.testConnection(configuration: config)
                }
            }

            for await connectionInfo in group {
                guard let connectionInfo else { continue }
                connectedCount += 1

                if connectionInfo.configuration.priority == 0 {
                    bestConnection = connectionInfo
                    group.cancelAll() // Stop further tasks if we found the highest-priority connection
                    break
                }

                if bestConnection == nil || connectionInfo.configuration.priority < bestConnection!.configuration.priority {
                    bestConnection = connectionInfo
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

    private func withTimeout<T: Sendable>(seconds: Double, operation: @escaping () async -> T?) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            // Start the operation
            group.addTask {
                await operation()
            }

            // Start the timeout countdown
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
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
            logger.info("testConnection for \(configuration.url)")
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
            logger.info("testConnection error - OpenAPIRuntime.RuntimeError encountered for \(configuration.url): \(openAPIError)")
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

    @MainActor
    private func setActiveConnection(_ connection: ConnectionInfo?) async {
        guard activeConnection != connection else { return }

        activeConnection = connection
        status = connection == nil ? .notConnected : .connected
        if let connection {
            KingfisherManager.shared.defaultOptions = [.requestModifier(OpenHABAccessTokenAdapter(connectionConfiguration: connection.configuration))]
        } else {
            startRetryTask(30)
        }
    }

    @MainActor
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

extension NetworkTracker: NetworkTracking {}

public extension NetworkTracker {
    func send(to item: OpenHABItem, command: String) async throws {
        try await send(to: item.name, command: command)
    }

    func send(to item: String, command: String) async throws {
        guard let activeConnection = await NetworkTracker.shared.waitForActiveConnection() else { return }
        let configuration = activeConnection.configuration
        let service = try await connectionPool.getOrCreateService(for: configuration)
        try await service.sendItemCommand(itemname: item, command: command)
    }

    func updateState(for item: OpenHABItem, state: String) async throws {
        guard let activeConnection = await NetworkTracker.shared.waitForActiveConnection() else { return }
        let configuration = activeConnection.configuration
        let service = try await connectionPool.getOrCreateService(for: configuration)
        try await service.updateItemState(itemname: item.name, with: state)
    }

    func getItems() async throws -> [OpenHABItem] {
        guard let activeConnection = await NetworkTracker.shared.waitForActiveConnection() else { return [] }
        let configuration = activeConnection.configuration
        let service = try await connectionPool.getOrCreateService(for: configuration)
        return try await service.getItems()
    }

    func getItemByName(id: String) async throws -> OpenHABItem? {
        guard let activeConnection = await NetworkTracker.shared.waitForActiveConnection() else { return nil }
        let configuration = activeConnection.configuration
        let service = try await connectionPool.getOrCreateService(for: configuration)
        return try await service.getItemByName(id: id)
    }

    func pollDataForPage(sitemapname: String, pageId: String = "", longPolling: Bool = false) async throws -> OpenHABPage? {
        guard let activeConnection = await NetworkTracker.shared.waitForActiveConnection() else { return nil }
        let configuration = activeConnection.configuration
        let service = try await connectionPool.getOrCreateService(for: configuration)
        return try await service.pollDataForPage(sitemapname: sitemapname, pageId: pageId, longPolling: longPolling)
    }

    func runNow(ruleUID: String, payload: [String: String]) async throws {
        guard let activeConnection = await NetworkTracker.shared.waitForActiveConnection() else { throw NetworkTrackerError.noActiveConnection }
        let configuration = activeConnection.configuration
        let service = try await connectionPool.getOrCreateService(for: configuration)
        try await service.runNow(ruleUID: ruleUID, payload: payload)
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
}

#if DEBUG
public extension NetworkTracker {
    func setMockConnection(_ connection: ConnectionInfo) {
        activeConnection = connection
    }
}
#endif
