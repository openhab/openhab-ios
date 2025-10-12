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
import Timeout

// TODO: these strings should reference Localizable keys
public enum NetworkStatus: String, Sendable {
    case started = "Started"
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
    private let logger = Logger(subsystem: "org.openhab.core", category: "ConnectionFailureTracker")

    func setConnections(_ connections: [ConnectionConfiguration]) {
        let connectionsBefore = failureCounts.keys
        logger.info("ConnectionFailureTracker: Setting connections for failure tracker.\nOld connections:\(ConnectionConfiguration.connectionConfigurationsToString(connectionsBefore))\nNew connections: \(ConnectionConfiguration.connectionConfigurationsToString(connections))")

        failureCounts = failureCounts.filter { connections.contains($0.key) }

        for key in connections where failureCounts[key] == nil {
            failureCounts[key] = 0
        }

        let connectionsAfter = failureCounts.keys
        logger.debug("ConnectionFailureTracker: Connections after update: \(ConnectionConfiguration.connectionConfigurationsToString(connectionsAfter))")
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
    @Published public var status: NetworkStatus = .stopped

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
        logger.info("NetworkTracker: Start Network Tracking for \(ConnectionConfiguration.connectionConfigurationsToString(connectionConfigurations))")

        let status = status // to prevent linter removing "self" in string interpolation
        guard status == .stopped || Set(connectionConfigurations) != Set(self.connectionConfigurations) else {
            logger.warning("NetworkTracker: Network tracking for these connections has already been started, current status: \(status.rawValue)")
            return
        }

        updateStatus(.started)

        await failureTracker.setConnections(connectionConfigurations)
        self.connectionConfigurations = connectionConfigurations
        setActiveConnection(nil)

        Task(priority: .userInitiated) {
            for configuration in connectionConfigurations {
                do {
                    _ = try await connectionPool.getOrCreateService(for: configuration)
                } catch {
                    logger.error("NetworkTracker: Failed to create service for config: \(configuration.url, privacy: .public) — \(error.localizedDescription)")
                    // Optionally: show a UI popup or skip to next config
                }
            }
            await attemptConnection()

            await self.pathMonitor.startMonitoring { [weak self] isConnected in
                await self?.handleNetworkChange(isConnected: isConnected)
            }
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
            logger.info("NetworkTracker: No connection from stopped network tracker possible")
            return nil
        }

        logger.info("NetworkTracker: waitForActiveConnection")
        // Utilize for await to listen for changes in $activeConnection
        // $activeConnection.values is an AsyncSequence, allowing you to iterate over its values asynchronously.
        // Wait until a non-nil value is received
        let logger = logger
        return try? await withThrowingTimeout(seconds: networkTimeout) { [self] in
            logger.info("NetworkTracker: Start waiting for active connection connection with timeout")
            let activeConnections = $activeConnection.values
            if status == .connected {
                // return existing conneciton
                if let current = activeConnection { return current }
            }
            for await connection in activeConnections {
                if let connection {
                    logger.info("NetworkTracker: active connection received")
                    return connection
                }
            }
            return nil
        }
    }

    // like startTracking but with the already configured connections and a fresh approach
    public func restartTracking() async {
        logger.debug("Networktracker: restartTracking")
        await failureTracker.resetAll() // just to make sure a few more connection attempts happen
        await startTracking(connectionConfigurations: connectionConfigurations)
    }

    // This gets called periodically when we have an active connection to make sure it's still the best choice
    private func checkActiveConnection() async {
        guard status != .stopped else {
            return
        }

        guard let activeConnection else {
            // No active connection, proceed with the normal connection attempt
            logger.info("NetworkTracker: No active connection, attempting to reconnect...")
            await attemptConnection()
            return
        }

        // Check if the active connection is reachable
        await makeBestConnectionActive()
        logger.debug("NetworkTracker: Active connection was reevaluated to be: \(activeConnection.configuration.url)")
    }

    private func attemptConnection() async {
        guard activeConnection == nil else {
            // with an active connection there is no need to attempt a reconnection
            return
        }

        var canAttemptAnyConnection = false
        for configuration in connectionConfigurations {
            let shouldAttempt = await failureTracker.shouldAttempt(configuration)
            canAttemptAnyConnection = canAttemptAnyConnection || shouldAttempt
        }

        guard canAttemptAnyConnection else {
            logger.error("NetworkTracker: No connection configurations available.")
            await stopTracking()
            return
        }

        updateStatus(.connecting)

        logger.debug("NetworkTracker: Checking available connections...")
        await makeBestConnectionActive()
    }

    private func makeBestConnectionActive() async {
        if let bestConnection = await findBestConnection() {
            logger.info("NetworkTracker: Best connection url: \(bestConnection.configuration.url) user: \(bestConnection.configuration.username)")
            setActiveConnection(bestConnection)
            updateStatus(.connected)
        } else {
            logger.info("NetworkTracker: No connection succeeded")
            setActiveConnection(nil)
            updateStatus(.started)
        }
    }

    /// Search for available connections among connectionConfigurations
    /// When the first one was found, we wait a small grace period if there is a preferred one that also works
    private func findBestConnection() async -> ConnectionInfo? {
        await withTaskGroup(of: ConnectionInfo?.self, returning: ConnectionInfo?.self) { group in
            let sortedConfigs = connectionConfigurations.sorted { $0.priority < $1.priority }

            for config in sortedConfigs {
                _ = group.addTaskUnlessCancelled {
                    let connection = await self.testConnection(configuration: config)
                    return connection
                }
            }

            var currentBestConnection: ConnectionInfo?

            try? await withThrowingTimeout(seconds: networkTimeout) { timeoutController in
                for await connectionInfo in group {
                    guard let connectionInfo else { continue }

                    if currentBestConnection == nil {
                        logger.debug("NetworkTracker: First working connection found: \(connectionInfo.configuration.url)")
                        currentBestConnection = connectionInfo
                        // give the other connections a short time to be found, otherwise cancel early
                        timeoutController.expire(seconds: NetworkTracker.slowConnectionTimeout)
                    } else if let bestConnection = currentBestConnection, connectionInfo.configuration.priority < bestConnection.configuration.priority {
                        logger.debug("NetworkTracker: Better connection found: \(connectionInfo.configuration.url)")
                        currentBestConnection = connectionInfo
                    }

                    if currentBestConnection?.configuration.priority == 0 {
                        logger.debug("NetworkTracker: Most prioritized connection with url: \(connectionInfo.configuration.url) and user: \(connectionInfo.configuration.username) tested successfully")
                        // Stop further tasks if we found the highest-priority connection and return it
                        group.cancelAll()
                        return
                    }
                }
            }

            let bestConnectionUrl = currentBestConnection?.configuration.url ?? "none"
            logger.debug("NetworkTracker: Best connection: \(bestConnectionUrl)")
            return currentBestConnection
        }
    }

    /// tests connectivity for a given connection, but at most until timeout
    private func testConnection(configuration: ConnectionConfiguration) async -> ConnectionInfo? {
        guard URL(string: configuration.url) != nil else { return nil }

        let shouldTry = await failureTracker.shouldAttempt(configuration)
        let reevaluating = activeConnection != nil
        // attempt the other possibly frequently failed connection, too, when reevaluating best connection
        if !(reevaluating || shouldTry) {
            logger.info("NetworkTracker: Skipping \(configuration.url) due to repeated failures.")
            return nil
        }

        do {
            logger.info("NetworkTracker: testConnection for url: \(configuration.url) user: \(configuration.username)")
            let connection = try await connectionPool.getOrCreateService(for: configuration)
            let version = try await connection.getRootVersion()
            let connectionInfo = ConnectionInfo(configuration: configuration, version: version)

            await failureTracker.reset(configuration) // Reset on success
            logger.info("NetworkTracker: testConnection successful for \(configuration.url)")
            return connectionInfo
        } catch is CancellationError {
            logger.debug("NetworkTracker: Cancelled connection attempt to \(configuration.url)")
        } catch NetworkTrackerError.invalidServerVersion {
            logger.info("NetworkTracker: testConnection error - Invalid server version from \(configuration.url)")
            await failureTracker.recordFailure(configuration)
        } catch let error as OpenAPIServiceError {
            switch error {
            case let .undocumented(statusCode, payload):
                logger.info("NetworkTracker: Undocumented status code: \(statusCode), payload: \(String(describing: payload))")
            default: break
            }
        } catch let openAPIError as OpenAPIRuntime.ClientError {
            logger.info("Networktracker: testConnection error - OpenAPIRuntime.RuntimeError encountered for \(configuration.url)")
            // logger.debug("OpenAPIRuntime.RuntimeError is \(openAPIError)")
        } catch {
            logger.info("NetworkTracker: testConnection error - Failed to connect to \(configuration.url) \(error.localizedDescription)")
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
            logger.info("NetworkTracker: Retrying connection in \(delay) seconds based on failure count of \(failureCount).")
            try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
            await attemptConnection()
        }
    }

    /// keep trying to connect when network is not connected, otherwise check if active connection is actually available
    private func handleNetworkChange(isConnected: Bool) async {
        guard status != .stopped else {
            return
        }

        if isConnected {
            logger.info("NetworkTracker: Networkmonitor status: Connected")
            await checkActiveConnection()
        } else {
            logger.info("NetworkTracker: Networkmonitor status: Disconnected, stopping connection attempts")
            setActiveConnection(nil)
            // don´t retry until we have a network connection again
            retryTask?.cancel()
        }
    }

    private func setActiveConnection(_ connection: ConnectionInfo?) {
        guard activeConnection != connection else { return }

        activeConnection = connection

        if let connection {
            // TODO: suspicious call to "shared" instance with specific connection
            KingfisherManager.shared.defaultOptions = [.requestModifier(OpenHABAccessTokenAdapter(connectionConfiguration: connection.configuration))]
        } else if status != .stopped {
            startRetryTask(UInt64(networkTimeout) * 2)
        }
    }

    private func updateStatus(_ newStatus: NetworkStatus) {
        guard status != newStatus else { return } // Prevent redundant updates
        status = newStatus
        logger.info("NetworkTracker: status updated: \(newStatus.rawValue)")
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
