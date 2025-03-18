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

import Combine
import Foundation
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
}

public enum NetworkTrackerError: Error, CustomDebugStringConvertible {
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
actor ConnectionPool {
    private var services: [ConnectionConfiguration: OpenAPIService] = [:]

    @discardableResult
    func getOrCreateService(for configuration: ConnectionConfiguration) async -> OpenAPIService {
        if let existingService = services[configuration] {
            return existingService
        }
        let newService = OpenAPIService(
            connectionConfiguration: configuration,
            configuration: .shortTerm
        )
        services[configuration] = newService
        return newService
    }

    // Ensures that all URLs pointing to "myopenhab.org" are standardized to "home.myopenhab.org".
    private func adjustMyOpenHABHosts(in configurations: [ConnectionConfiguration]) -> [ConnectionConfiguration] {
        configurations.map { configuration in
            adjustMyOpenHABHost(in: configuration)
        }
    }

    private func adjustMyOpenHABHost(in configuration: ConnectionConfiguration) -> ConnectionConfiguration {
        var updatedURL = configuration.url
        if let urlComponents = URLComponents(string: configuration.url),
           let host = urlComponents.host,
           host.contains("myopenhab.org"),
           host != "home.myopenhab.org" {
            var newComponents = urlComponents
            newComponents.host = "home.myopenhab.org"
            updatedURL = newComponents.url?.absoluteString ?? configuration.url
        }
        return ConnectionConfiguration(url: updatedURL, username: configuration.username, password: configuration.password, priority: configuration.priority)
    }
}

public final class NetworkTracker: ObservableObject {
    public static let shared = NetworkTracker()

    @Published public private(set) var activeConnection: ConnectionInfo?
    @Published public private(set) var status: NetworkStatus = .connecting

    private var retryCount = 0
    private let maxRetries = 5
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue.global(qos: .background)
    private var connectionPool: ConnectionPool = .init()
    private var connectionConfigurations: [ConnectionConfiguration] = []
    private var retryTask: Task<Void, Never>?
    public private(set) var httpClient: HTTPClient?
    public var clientCertificateManager = ClientCertificateManager()
    public var serverCertificateManager = ServerCertificateManager()
    private let disconnectedRetryInterval: UInt64 = 30 // / amount of time we scan when not connected

    private let logger = Logger(subsystem: "org.openhab.core", category: "NetworkTracker")

    private init() {
//        if #available(iOS 17, watchOS 10, *) {
//            // The `for await` loop automatically handles updates from NWPathMonitor, so there’s no need for a callback.
//            Task {
//                let monitor = NWPathMonitor()
//                for await path in monitor {
//                    await handleNetworkChange(isConnected: path.status == .satisfied)
//                }
//            }
//        } else {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { await self?.handleNetworkChange(isConnected: path.status == .satisfied) }
        }
        monitor.start(queue: monitorQueue)
    }

    public func startTracking(connectionConfigurations: [ConnectionConfiguration]) {
        logger.info("Start Network Tracking")
//        self.connectionConfigurations = adjustMyOpenHABHosts(in: connectionConfigurations)
        self.connectionConfigurations = connectionConfigurations
        Task {
            for configuration in connectionConfigurations {
                await connectionPool.getOrCreateService(for: configuration)
            }
            await setActiveConnection(nil)
            await attemptConnection()
        }
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
            logger.info("Active connection is reachable: \(activeConnection.configuration.url)")
        } catch {
            logger.error("Active connection failed: \(activeConnection.configuration.url) - \(error.localizedDescription)")
            await attemptConnection()
        }
    }

    private func attemptConnection() async {
        guard !connectionConfigurations.isEmpty else {
            logger.error("No connection configurations available.")
            await setActiveConnection(nil)
            return
        }

        logger.info("Checking available connections...")

        let bestConnection = await findBestConnection()
        await setActiveConnection(bestConnection)
    }

    private func findBestConnection() async -> ConnectionInfo? {
        let sortedConfigs = connectionConfigurations.sorted { $0.priority < $1.priority }
        var bestConnection: ConnectionInfo?
        // var connectedCounts = 0

        await withTaskGroup(of: ConnectionInfo?.self) { group in
            for config in sortedConfigs {
                group.addTask {
                    await self.testConnection(configuration: config)
                }
            }

            for await connectionInfo in group {
                guard let connectionInfo else { continue }

                if connectionInfo.configuration.priority == 0 {
                    bestConnection = connectionInfo
//                    group.cancelAll() // Stop further tasks if we found the highest-priority connection
                    break
                }

                if bestConnection == nil || connectionInfo.configuration.priority < bestConnection!.configuration.priority {
                    bestConnection = connectionInfo
                }
            }
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

        do {
            logger.info("testConnection for \(configuration.url)")
            let connection = await connectionPool.getOrCreateService(for: configuration)
            let version = try await connection.getRootVersion()
            let connectionInfo = ConnectionInfo(configuration: configuration, version: version)
            logger.info("testConnection successful for \(configuration.url)")
            return connectionInfo
        } catch NetworkTrackerError.invalidServerVersion {
            logger.info("testConnection error - Invalid server version from \(configuration.url)")
            return nil
        } catch let openAPIError as OpenAPIRuntime.ClientError {
            logger.info("testConnection error - OpenAPIRuntime.RuntimeError encountered for \(configuration.url): \(openAPIError)")
            return nil
        } catch {
            logger.info("testConnection error - Failed to connect to \(configuration.url) \(error.localizedDescription)")
            return nil
        }
    }

    private func startRetryTask(_ retryInterval: UInt64) {
        retryTask?.cancel()
        retryTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(retryInterval * 1_000_000_000))
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
            startRetryTask(10)
        }
    }

    // Ensures that all URLs pointing to "myopenhab.org" are standardized to "home.myopenhab.org".
    private func adjustMyOpenHABHosts(in configurations: [ConnectionConfiguration]) -> [ConnectionConfiguration] {
        configurations.map { configuration in
            adjustMyOpenHABHost(in: configuration)
        }
    }

    private func adjustMyOpenHABHost(in configuration: ConnectionConfiguration) -> ConnectionConfiguration {
        var updatedURL = configuration.url
        if let urlComponents = URLComponents(string: configuration.url),
           let host = urlComponents.host,
           host.contains("myopenhab.org"),
           host != "home.myopenhab.org" {
            var newComponents = urlComponents
            newComponents.host = "home.myopenhab.org"
            updatedURL = newComponents.url?.absoluteString ?? configuration.url
        }
        return ConnectionConfiguration(url: updatedURL, username: configuration.username, password: configuration.password, priority: configuration.priority)
    }

    @MainActor
    private func setActiveConnection(_ connection: ConnectionInfo?) async {
        guard activeConnection != connection else { return }

        activeConnection = connection
        if activeConnection != nil {
            status = .connected
        } else {
            status = .notConnected
            startRetryTask(disconnectedRetryInterval)
        }
    }
}

public extension NetworkTracker {
    func send(to item: OpenHABItem, command: String) async throws {
        try await send(to: item.name, command: command)
    }

    func send(to item: String, command: String) async throws {
        guard let activeConnection = await NetworkTracker.shared.waitForActiveConnection() else { return }
        let configuration = activeConnection.configuration
        let service = await connectionPool.getOrCreateService(for: configuration)
        try await service.sendItemCommand(itemname: item, command: command)
    }

    func updateState(for item: OpenHABItem, state: String) async throws {
        guard let activeConnection = await NetworkTracker.shared.waitForActiveConnection() else { return }
        let configuration = activeConnection.configuration
        let service = await connectionPool.getOrCreateService(for: configuration)
        try await service.updateItemState(itemname: item.name, with: state)
    }

    func getItems() async throws -> [OpenHABItem] {
        guard let activeConnection = await NetworkTracker.shared.waitForActiveConnection() else { return [] }
        let configuration = activeConnection.configuration
        let service = await connectionPool.getOrCreateService(for: configuration)
        return try await service.getItems()
    }

    func getItemByName(id: String) async throws -> OpenHABItem? {
        guard let activeConnection = await NetworkTracker.shared.waitForActiveConnection() else { return nil }
        let configuration = activeConnection.configuration
        let service = await connectionPool.getOrCreateService(for: configuration)
        return try await service.getItemByName(id: id)
    }

    func pollDataForPage(sitemapname: String, pageId: String = "", longPolling: Bool = false) async throws -> OpenHABPage? {
        guard let activeConnection = await NetworkTracker.shared.waitForActiveConnection() else { return nil }
        let configuration = activeConnection.configuration
        let service = await connectionPool.getOrCreateService(for: configuration)
        return try await service.pollDataForPage(sitemapname: sitemapname, pageId: pageId, longPolling: longPolling)
    }

    func runNow(ruleUID: String, payload: [String: String]) async throws {
        guard let activeConnection = await NetworkTracker.shared.waitForActiveConnection() else { throw NetworkTrackerError.noActiveConnection }
        let configuration = activeConnection.configuration
        let service = await connectionPool.getOrCreateService(for: configuration)
        try await service.runNow(ruleUID: ruleUID, payload: payload)
    }
}

public extension NetworkTracker {
    func activeConnectionStream() -> AsyncStream<ConnectionInfo?> {
        AsyncStream { continuation in
            let cancellable = self.$activeConnection
                .sink { continuation.yield($0) }

            continuation.onTermination = { _ in cancellable.cancel() }
        }
    }
}
