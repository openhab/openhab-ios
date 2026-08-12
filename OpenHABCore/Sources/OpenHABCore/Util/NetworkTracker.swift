// Copyright (c) 2010-2026 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Combine
import Foundation
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
    public let proxyURL: URL?

    // Explicit public memberwise initializer
    public init(configuration: ConnectionConfiguration, version: Int, proxyURL: URL? = nil) {
        self.configuration = configuration
        self.version = version
        self.proxyURL = proxyURL
    }
}

/// A snapshot of the network tracker's observable state, delivered as a single value so
/// consumers observe one coherent update rather than reconciling several parallel streams.
public struct NetworkState: Equatable, Sendable, CustomStringConvertible {
    
    public let activeConnection: ConnectionInfo?
    public let status: NetworkStatus
    /// When another connection attempt is scheduled, the time it will fire; `nil` otherwise.
    public let nextRetryDate: Date?
    /// Whether the device currently has a usable network path.
    public let isNetworkAvailable: Bool
    
    public var description: String { "status: \(status.rawValue), activeConnection: \(activeConnection?.configuration.description ?? "nil"), next retry: \(nextRetryDate?.description ?? "nil"), network available: \(isNetworkAvailable ? "yes" : "no")" }

    public init(activeConnection: ConnectionInfo?, status: NetworkStatus, nextRetryDate: Date?, isNetworkAvailable: Bool) {
        self.activeConnection = activeConnection
        self.status = status
        self.nextRetryDate = nextRetryDate
        self.isNetworkAvailable = isNetworkAvailable
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
    // swiftlint:disable:next async_without_await
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
    private var enabled = false
    private var failureCounts: [ConnectionConfiguration: Int] = [:]
    private let maxFailures = 3

    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
    }

    func setConnections(_ connections: [ConnectionConfiguration]) {
        let connectionsBefore = failureCounts.keys
        Logger.connectionFailureTracker.info("""
        ConnectionFailureTracker: Setting connections for failure tracker.
            Old connections: \(connectionsBefore.sorted(by: \.url).map { "\($0)" }, privacy: .private)
            New connections: \(connections.sorted(by: \.url).map { "\($0)" }, privacy: .private)
        """)

        failureCounts = failureCounts.filter { connections.contains($0.key) }

        for key in connections where failureCounts[key] == nil {
            failureCounts[key] = 0
        }

        let connectionsAfter = failureCounts.keys
        Logger.connectionFailureTracker.debug("ConnectionFailureTracker: Connections after update: \(connectionsAfter.sorted(by: \.url).map { "\($0)" }, privacy: .private)")
    }

    func shouldAttempt(_ config: ConnectionConfiguration) -> Bool {
        (failureCounts[config] ?? 0) < maxFailures
    }

    func recordFailure(_ config: ConnectionConfiguration) {
        guard enabled else {
            Logger.connectionFailureTracker.debug("ConnectionFailureTracker: Do not record failure while being disabled for connection url \(config.url) user: \(config.username, privacy: .private)")
            return
        }
        Logger.connectionFailureTracker.debug("ConnectionFailureTracker: Record failure for connection url \(config.url) user: \(config.username, privacy: .private)")
        failureCounts[config, default: 0] += 1
    }

    func reset(_ config: ConnectionConfiguration) {
        Logger.connectionFailureTracker.debug("ConnectionFailureTracker: Reset failures for connection url \(config.url) user: \(config.username)")
        failureCounts[config] = 0
    }

    func resetAll() {
        Logger.connectionFailureTracker.debug("ConnectionFailureTracker: Reset all failures")
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
    @Published public var nextRetryDate: Date?
    @Published public var isNetworkAvailable = true

    public init(tracker: NetworkTracker = NetworkTracker.shared) {
        Task {
            for await state in await tracker.stateStream() {
                activeConnection = state.activeConnection
                status = state.status
                nextRetryDate = state.nextRetryDate
                isNetworkAvailable = state.isNetworkAvailable
            }
        }
    }
}

public actor CertificateManagers {
    @MainActor public static let clientCertificateManager = ClientCertificateManager()
    @MainActor public static let serverCertificateManager = ServerCertificateManager()
    public static let certificateStore = CertificateStore.shared
}

public actor NetworkTracker {
    public static let shared = NetworkTracker()

    public static let networkTimeout: TimeInterval = 10
    public static let slowConnectionTimeout: TimeInterval = 1

    public private(set) var activeConnection: ConnectionInfo?
    public private(set) var status: NetworkStatus = .stopped

    /// When a connection attempt has failed and another attempt is scheduled, the wall-clock
    /// time that retry will fire; `nil` while connecting/connected or once tracking has given
    /// up. Lets the UI count down to the next attempt.
    public private(set) var nextRetryDate: Date?

    /// Whether the device currently has a usable network path. `false` means retries are
    /// abandoned until the network returns; lets the UI distinguish "no network" from
    /// "server unreachable".
    public private(set) var isNetworkAvailable = true

    // Registered observers: each call to stateStream() gets its own continuation entry.
    private var stateContinuations: [UUID: AsyncStream<NetworkState>.Continuation] = [:]

    private var pathMonitor: any NWPathMonitoring
    private var connectionPool: ConnectionPool
    private var connectionConfigurations: [ConnectionConfiguration] = []

    private var retryTask: Task<Void, Never>?

    private var failureTracker: ConnectionFailureTracker

    private var networkTimeout = NetworkTracker.networkTimeout

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
        Logger.networkTracker.info("NetworkTracker: Start Network Tracking for \(connectionConfigurations.sorted(by: \.url).map { "\($0)" }, privacy: .private)")

        let status = status // to prevent linter removing "self" in string interpolation
        guard status == .stopped || Set(connectionConfigurations) != Set(self.connectionConfigurations) else {
            Logger.networkTracker.warning("NetworkTracker: Network tracking for these connections has already been started, current status: \(status.rawValue)")
            return
        }

        retryTask?.cancel()
        retryTask = nil

        updateStatus(.started)

        await failureTracker.setConnections(connectionConfigurations)
        self.connectionConfigurations = connectionConfigurations
        setActiveConnection(nil)

        Task(priority: .userInitiated) {
            for configuration in connectionConfigurations {
                do {
                    _ = try await connectionPool.getOrCreateService(for: configuration)
                } catch {
                    Logger.networkTracker.error("NetworkTracker: Failed to create service for config: \(configuration.url, privacy: .public) — \(error.localizedDescription)")
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
        nextRetryDate = nil
        pathMonitor.cancel()
        setActiveConnection(nil)
        await failureTracker.resetAll()
        updateStatus(.stopped)
    }

    /// This function will pause execution until either an active connection was found or the timeout has been reached
    public func waitForActiveConnection() async -> ConnectionInfo? {
        guard status != .stopped else {
            Logger.networkTracker.info("NetworkTracker: No connection from stopped network tracker possible")
            return nil
        }

        Logger.networkTracker.info("NetworkTracker: waitForActiveConnection")
        // stateStream() replays the current state immediately, so the loop returns
        // right away when already connected and waits for the next change otherwise.
        return try? await withThrowingTimeout(seconds: networkTimeout) { [self] in
            Logger.networkTracker.info("NetworkTracker: Start waiting for active connection connection with timeout")
            for await state in stateStream() {
                if let connection = state.activeConnection {
                    Logger.networkTracker.info("NetworkTracker: active connection received")
                    return connection
                }
            }
            return nil
        }
    }

    // like startTracking but with the already configured connections and a fresh approach
    public func restartTracking() async {
        Logger.networkTracker.debug("Networktracker: restartTracking")
        await failureTracker.resetAll() // just to make sure a few more connection attempts happen if necessary
        if status != .connected {
            await stopTracking()
        }
        await startTracking(connectionConfigurations: connectionConfigurations)
    }

    // This gets called periodically when we have an active connection to make sure it's still the best choice
    private func checkActiveConnection() async {
        guard status != .stopped else {
            return
        }

        guard let activeConnection else {
            // No active connection, proceed with the normal connection attempt. This runs only
            // on a meaningful network change (the path monitor filters out quality-only noise),
            // so attempting now — and letting it reschedule the backoff — is appropriate.
            Logger.networkTracker.info("NetworkTracker: No active connection, attempting to reconnect...")
            await attemptConnection(silent: true)
            return
        }

        // Check if the active connection is reachable
        await makeBestConnectionActive()
        Logger.networkTracker.debug("NetworkTracker: Active connection was reevaluated to be: \(activeConnection.configuration.publicLogDescription, privacy: .public)")
    }

    private func attemptConnection(silent: Bool = false) async {
        guard activeConnection == nil else {
            // with an active connection there is no need to attempt a reconnection
            return
        }

        guard await canAttemptAnyConnection() else {
            Logger.networkTracker.error("NetworkTracker: No connection configurations available.")
            await stopTracking()
            return
        }

        if !silent {
            updateStatus(.connecting)
        }

        Logger.networkTracker.debug("NetworkTracker: Checking available connections...")
        await makeBestConnectionActive()
    }

    private func canAttemptAnyConnection() async -> Bool {
        var canAttemptAnyConnection = false
        for configuration in connectionConfigurations {
            let shouldAttempt = await failureTracker.shouldAttempt(configuration)
            canAttemptAnyConnection = canAttemptAnyConnection || shouldAttempt
        }
        return canAttemptAnyConnection
    }

    private func makeBestConnectionActive() async {
        if let bestConnection = await findBestConnection() {
            Logger.networkTracker.info("NetworkTracker: Best connection \(bestConnection.configuration.publicLogDescription, privacy: .public)")
            nextRetryDate = nil
            setActiveConnection(bestConnection)
            updateStatus(.connected)
        } else {
            Logger.networkTracker.info("NetworkTracker: No connection succeeded")
            setActiveConnection(nil)
            if await canAttemptAnyConnection() {
                updateStatus(.started)
                await scheduleRetry(UInt64(networkTimeout))
            } else {
                await stopTracking()
            }
        }
    }

    /// Search for available connections among connectionConfigurations
    /// When the first one was found, we wait a small grace period if there is a preferred one that also works
    private func findBestConnection() async -> ConnectionInfo? {
        enum ConnectionSearchResult: Sendable {
            case connection(ConnectionInfo?)
            case gracePeriodExpired
            case networkTimeoutExpired
        }

        return await withTaskGroup(of: ConnectionSearchResult.self, returning: ConnectionInfo?.self) { group in
            let sortedConfigs = connectionConfigurations.sorted { $0.priority < $1.priority }

            for config in sortedConfigs {
                _ = group.addTaskUnlessCancelled {
                    let connection = await self.testConnection(configuration: config)
                    return .connection(connection)
                }
            }

            group.addTask {
                try? await Task.sleep(for: .seconds(self.networkTimeout))
                return .networkTimeoutExpired
            }

            var currentBestConnection: ConnectionInfo?
            var gracePeriodStarted = false
            var pendingConnectionCount = sortedConfigs.count

            while let result = await group.next() {
                switch result {
                case let .connection(connectionInfo):
                    guard let connectionInfo else {
                        pendingConnectionCount -= 1
                        // All connections failed with no candidate found — cancel the timeout sentinel
                        // and return immediately rather than waiting up to networkTimeout seconds.
                        if pendingConnectionCount == 0, currentBestConnection == nil {
                            group.cancelAll()
                            return nil
                        }
                        continue
                    }

                    if currentBestConnection == nil {
                        Logger.networkTracker.debug("NetworkTracker: First working connection found: \(connectionInfo.configuration.publicLogDescription, privacy: .public)")
                        currentBestConnection = connectionInfo
                        if connectionInfo.configuration.priority == 0 {
                            Logger.networkTracker.debug("NetworkTracker: Most prioritized connection \(connectionInfo.configuration.publicLogDescription, privacy: .public) tested successfully")
                            group.cancelAll()
                            Logger.networkTracker.debug("NetworkTracker: Best connection: \(connectionInfo.configuration.publicLogDescription, privacy: .public)")
                            return currentBestConnection
                        }
                        if !gracePeriodStarted {
                            gracePeriodStarted = true
                            // Grace window: give remaining connections a short time to respond.
                            // Adding this as a child task ensures group.cancelAll() propagates into
                            // slow connections when the window fires
                            group.addTask {
                                try? await Task.sleep(for: .seconds(NetworkTracker.slowConnectionTimeout))
                                return .gracePeriodExpired
                            }
                        }
                    } else if let bestConnection = currentBestConnection, connectionInfo.configuration.priority < bestConnection.configuration.priority {
                        Logger.networkTracker.debug("NetworkTracker: Better connection found: \(connectionInfo.configuration.publicLogDescription, privacy: .public)")
                        currentBestConnection = connectionInfo
                    }

                    if currentBestConnection?.configuration.priority == 0 {
                        Logger.networkTracker.debug("NetworkTracker: Most prioritized connection \(connectionInfo.configuration.publicLogDescription, privacy: .public) tested successfully")
                        // Stop further tasks if we found the highest-priority connection and return it
                        group.cancelAll()
                        let bestConnectionUrl = currentBestConnection?.configuration.publicLogDescription ?? "none"
                        Logger.networkTracker.debug("NetworkTracker: Best connection: \(bestConnectionUrl)")
                        return currentBestConnection
                    }

                case .gracePeriodExpired:
                    guard currentBestConnection != nil else { continue }
                    Logger.networkTracker.debug("NetworkTracker: Preferred connection grace period expired")
                    group.cancelAll()
                    let bestConnectionUrl = currentBestConnection?.configuration.publicLogDescription ?? "none"
                    Logger.networkTracker.debug("NetworkTracker: Best connection: \(bestConnectionUrl)")
                    return currentBestConnection

                case .networkTimeoutExpired:
                    Logger.networkTracker.debug("NetworkTracker: Connection search timeout expired")
                    group.cancelAll()
                    let bestConnectionUrl = currentBestConnection?.configuration.publicLogDescription ?? "none"
                    Logger.networkTracker.debug("NetworkTracker: Best connection: \(bestConnectionUrl)")
                    return currentBestConnection
                }
            }

            let bestConnectionUrl = currentBestConnection?.configuration.publicLogDescription ?? "none"
            Logger.networkTracker.debug("NetworkTracker: Best connection: \(bestConnectionUrl)")
            return currentBestConnection
        }
    }

    private func fetchProxyURL(for config: ConnectionConfiguration) async -> URL? {
        guard config.isCloudConnection,
              let baseURL = URL(string: config.url) else { return nil }
        let proxyEndpoint = baseURL.appendingPathComponent("api/v1/proxyurl")
        var request = URLRequest(url: proxyEndpoint)
        request.timeoutInterval = 5
        if !config.username.isEmpty, !config.password.isEmpty {
            request.setValue(
                basicAuthHeader(username: config.username, password: config.password),
                forHTTPHeaderField: "Authorization"
            )
        }
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONDecoder().decode([String: String].self, from: data)
            if let urlString = json["url"] { return URL(string: urlString) }
        } catch {
            Logger.networkTracker.info("NetworkTracker: Failed to fetch proxyURL: \(error.localizedDescription)")
        }
        return nil
    }

    /// tests connectivity for a given connection, but at most until timeout
    private func testConnection(configuration: ConnectionConfiguration) async -> ConnectionInfo? {
        guard URL(string: configuration.url) != nil else { return nil }

        let shouldTry = await failureTracker.shouldAttempt(configuration)
        let reevaluating = activeConnection != nil
        // attempt the other possibly frequently failed connection, too, when reevaluating best connection
        if !(reevaluating || shouldTry) {
            Logger.networkTracker.info("NetworkTracker: Skipping \(configuration.publicLogDescription, privacy: .public) due to repeated failures.")
            return nil
        }

        do {
            Logger.networkTracker.info("NetworkTracker: testConnection for \(configuration.publicLogDescription, privacy: .public)")
            let connection = try await connectionPool.getOrCreateService(for: configuration)
            let version = try await connection.getRootVersion()
            let proxyURL = await fetchProxyURL(for: configuration)
            let connectionInfo = ConnectionInfo(configuration: configuration, version: version, proxyURL: proxyURL)

            await failureTracker.reset(configuration) // Reset on success
            Logger.networkTracker.info("NetworkTracker: testConnection successful for \(configuration.publicLogDescription, privacy: .public), version: \(version, privacy: .public)")
            return connectionInfo
        } catch is CancellationError {
            Logger.networkTracker.debug("NetworkTracker: Cancelled connection attempt to \(configuration.publicLogDescription, privacy: .public)")
        } catch NetworkTrackerError.invalidServerVersion {
            await failureTracker.recordFailure(configuration)
            Logger.networkTracker.info("NetworkTracker: testConnection error - Invalid server version from \(configuration.publicLogDescription, privacy: .public)")
        } catch let error as OpenAPIServiceError {
            await failureTracker.recordFailure(configuration)
            switch error {
            case let .undocumented(statusCode, payload):
                Logger.networkTracker.info("NetworkTracker: Undocumented status code: \(statusCode), payload: \(String(describing: payload))")
            default: break
            }
        } catch let openAPIError as OpenAPIRuntime.ClientError {
            await failureTracker.recordFailure(configuration)
            Logger.networkTracker.info("Networktracker: testConnection error - OpenAPIRuntime.RuntimeError encountered for \(configuration.publicLogDescription, privacy: .public)")
            Logger.networkTracker.debug("OpenAPIRuntime.RuntimeError is \(openAPIError)")
        } catch {
            await failureTracker.recordFailure(configuration)
            Logger.networkTracker.info("NetworkTracker: testConnection error - Failed to connect to \(configuration.publicLogDescription, privacy: .public) \(error.localizedDescription)")
        }

        return nil
    }

    /// attempt to connect with repeatedly longer intervals
    private func scheduleRetry(_ initialRetryInterval: UInt64) async {
        retryTask?.cancel()
        // prevent all non-retry failures from being recorded
        await failureTracker.setEnabled(false)
        let failureCount = await failureTracker.maxFailureCount()
        let backoffMultiplier = UInt64(failureCount)
        let safeBackoff = min(backoffMultiplier, 10) // 2^10 = 1024
        let delay = min(initialRetryInterval * (1 << safeBackoff), 300)
        Logger.networkTracker.info("NetworkTracker: Retrying connection in \(delay) seconds based on failure count of \(failureCount).")
        // Publish the retry deadline so the UI can count down to it.
        nextRetryDate = Date().addingTimeInterval(TimeInterval(delay))
        yieldCurrentState()
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.beginScheduledRetry()
        }
    }

    /// Runs when a scheduled retry fires: clears the retry deadline and re-attempts,
    /// allowing failures from this attempt to be recorded again.
    private func beginScheduledRetry() async {
        nextRetryDate = nil
        yieldCurrentState()
        await failureTracker.setEnabled(true)
        await attemptConnection()
    }

    /// Clears the active connection and rediscovers the best available one.
    /// Use after a transport failure to recover from a stale connection (e.g. network switched while process was suspended).
    private func revalidateConnection() async {
        Logger.networkTracker.info("NetworkTracker: Re-evaluating connection after transport failure")
        setActiveConnection(nil)
        await failureTracker.resetAll()
        await attemptConnection()
    }

    /// keep trying to connect when network is not connected, otherwise check if active connection is actually available
    private func handleNetworkChange(isConnected: Bool) async {
        guard status != .stopped else {
            return
        }

        Logger.networkTracker.info("NetworkTracker: Networkmonitor status: \(isConnected ? "connected" : "disconnected")")
        isNetworkAvailable = isConnected
        yieldCurrentState()

        // Network is down: abandon the backoff retry — there is no point hammering a dead
        // interface, and the next network-up event will drive a fresh attempt.
        guard isConnected else {
            retryTask?.cancel()
            nextRetryDate = nil
            yieldCurrentState()
            return
        }

        await checkActiveConnection()
    }

    private func setActiveConnection(_ connection: ConnectionInfo?) {
        guard status != .stopped else {
            if activeConnection != nil {
                activeConnection = nil
                yieldCurrentState()
            }
            return
        }

        if activeConnection != connection {
            activeConnection = connection
            yieldCurrentState()
        }
    }

    private func updateStatus(_ newStatus: NetworkStatus) {
        guard status != newStatus else { return } // Prevent redundant updates
        status = newStatus
        Logger.networkTracker.info("NetworkTracker: status updated: \(newStatus.rawValue)")
        yieldCurrentState()
    }

    private func yieldCurrentState() {
        let state = NetworkState(activeConnection: activeConnection, status: status, nextRetryDate: nextRetryDate, isNetworkAvailable: isNetworkAvailable)
        Logger.networkTracker.debug("NetworkTracker: yielding state \(state)")
        for cont in stateContinuations.values { cont.yield(state) }
    }

    private func removeStateContinuation(id: UUID) {
        stateContinuations.removeValue(forKey: id)
    }
}

public extension NetworkTracker {
    /// Finds the connection configuration whose URL host or proxy host matches the given host,
    /// prioritising the active connection.
    func connectionConfiguration(forHost host: String) -> ConnectionConfiguration? {
        if let activeConnection,
           activeConnection.configuration.host == host || activeConnection.proxyURL?.host == host {
            activeConnection.configuration
        } else {
            connectionConfigurations
                .filter { $0 != activeConnection?.configuration }
                .first { $0.host == host }
        }
    }

    private func service() async throws -> any OpenAPIServiceProtocol {
        guard let connection = await waitForActiveConnection()?.configuration else {
            throw NetworkTrackerError.noActiveConnection
        }
        guard let service = try? await connectionPool.getOrCreateService(for: connection) else {
            throw NetworkTrackerError.serviceUnavailable
        }
        return service
    }

    func send(to item: OpenHABItem, command: String, sourcePrefix: String? = nil, deviceId: String? = nil) async throws {
        try await send(to: item.name, command: command, sourcePrefix: sourcePrefix, deviceId: deviceId)
    }

    /// Retries once after revalidating the connection on two transient failure kinds:
    ///  • ClientError  — transport failure against a stale connection (network switch, suspension)
    ///  • noActiveConnection — all connection tests timed out during a network handoff; the
    ///    tracker recovers shortly after, so one revalidation + retry is enough.
    private func withClientErrorRetry<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch is OpenAPIRuntime.ClientError {
            await revalidateConnection()
            return try await operation()
        } catch NetworkTrackerError.noActiveConnection {
            await revalidateConnection()
            return try await operation()
        }
    }

    func send(to item: String, command: String, sourcePrefix: String? = nil, deviceId: String? = nil) async throws {
        try await withClientErrorRetry {
            try await service().sendItemCommand(itemname: item, command: command, sourcePrefix: sourcePrefix, deviceId: deviceId)
        }
    }

    func updateState(item: OpenHABItem, state: String, sourcePrefix: String? = nil, deviceId: String? = nil) async throws {
        try await withClientErrorRetry {
            try await service().updateItemState(itemname: item.name, with: state, sourcePrefix: sourcePrefix, deviceId: deviceId)
        }
    }

    func getStaticItems() async throws -> [OpenHABItem] {
        try await withClientErrorRetry {
            // staticDataOnly=true is intentionally omitted: it excludes dynamically-created
            // items (e.g. Shelly binding channel items), causing them to be missing from the
            // App Intents item cache and triggering re-prompts in Shortcuts.
            let items = try await service().getItems(query: Operations.getItems.Input.Query())
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    func getItemByName(id: String) async throws -> OpenHABItem? {
        try await withClientErrorRetry {
            try await service().getItemByName(id: id)
        }
    }

    func pollDataForPage(sitemapname: String, pageId: String = "", longPolling: Bool = false) async throws -> OpenHABPage? {
        try await service().pollDataForPage(sitemapname: sitemapname, pageId: pageId, longPolling: longPolling)
    }

    func runNow(ruleUID: String, payload: [String: String]) async throws {
        try await service().runNow(ruleUID: ruleUID, payload: payload)
    }
}

public extension NetworkTracker {
    /// A single stream combining active connection, status and the retry deadline, so a
    /// consumer receives one coherent `NetworkState` per change instead of interleaving
    /// several streams.
    /// Returns an AsyncStream that immediately yields the current NetworkState,
    /// then yields a fresh coherent snapshot on every subsequent change.
    /// Safe to call from any Swift concurrent context.
    func stateStream() -> AsyncStream<NetworkState> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: NetworkState.self)
        stateContinuations[id] = continuation
        continuation.yield(NetworkState(activeConnection: activeConnection, status: status, nextRetryDate: nextRetryDate, isNetworkAvailable: isNetworkAvailable))
        continuation.onTermination = { [weak self] _ in
            Task { [weak self] in await self?.removeStateContinuation(id: id) }
        }
        return stream
    }
}

#if DEBUG
public extension NetworkTracker {
    func setMockConnection(_ connection: ConnectionInfo) {
        activeConnection = connection
    }

    func setMockConnectionConfigurations(_ configurations: [ConnectionConfiguration]) {
        connectionConfigurations = configurations
    }
}
#endif
