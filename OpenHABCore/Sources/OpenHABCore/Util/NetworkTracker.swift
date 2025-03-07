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
import os.log

// TODO: these strings should reference Localizable keys
public enum NetworkStatus: String {
    case connecting = "Connecting"
    case connected = "Connected"
    case notConnected = "Not Connected"
    case someConnected = "Some Connected"
    case allConnected = "All Connected"
}

public struct ConnectionConfiguration: Hashable {
    public let url: String
    public let priority: Int // Lower is higher priority, 0 is primary

    public init(url: String, priority: Int = 10) {
        self.url = url
        self.priority = priority
    }
}

public struct ConnectionInfo: Equatable {
    public let configuration: ConnectionConfiguration
    public let version: Int
}

enum NetworkTrackerError: Error, CustomDebugStringConvertible {
    case invalidServerVersion
    case failedConnection(String)

    var debugDescription: String {
        switch self {
        case .invalidServerVersion: "Invalid server version"
        case let .failedConnection(url): "Failed to connect to \(url)"
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
        let newService = await OpenAPIService(
            baseURL: URL(string: configuration.url) ?? URL(staticString: "about:blank"),
            username: Preferences.username,
            password: Preferences.password,
            alwaysSendBasicAuth: Preferences.alwaysSendCreds,
            ignoreSSL: Preferences.ignoreSSL,
            configuration: .shortTerm
        )
        services[configuration] = newService
        return newService
    }
}

public final class NetworkTracker: ObservableObject {
    public static let shared = NetworkTracker()

    @Published public private(set) var activeConnection: ConnectionInfo?
    @Published public private(set) var status: NetworkStatus = .connecting

    private var retryCount = 0
    private let maxRetries = 5
    private let monitor: NWPathMonitor
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
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { await self?.handleNetworkChange(isConnected: path.status == .satisfied) }
        }
        monitor.start(queue: monitorQueue)
    }

//    private func getOrCreateService(for configuration: ConnectionConfiguration) async -> OpenAPIService {
//        if let cachedService = serviceCache[configuration.url] {
//            return cachedService
//        }
//
//        let newService = await OpenAPIService(
//            baseURL: URL(string: configuration.url),
//            username: Preferences.username,
//            password: Preferences.password
//        )
//
//        serviceCache[configuration.url] = newService
//        return newService
//    }

    public func startTracking(connectionConfigurations: [ConnectionConfiguration],
                              username: String,
                              password: String,
                              alwaysSendBasicAuth: Bool,
                              ignoreSSLVerification: Bool) {
        logger.info("Start Tracking")
        self.connectionConfigurations = adjustMyOpenHABHosts(in: connectionConfigurations)
        Task {
            for configuration in connectionConfigurations {
                await connectionPool.getOrCreateService(for: configuration)
            }
            await setActiveConnection(nil)
            await attemptConnection()
        }
    }

    public func waitForActiveConnection(timeout: TimeInterval = 10) async -> ConnectionInfo? {
        await withCheckedContinuation { continuation in
            let deadline = Date().addingTimeInterval(timeout)

            func checkConnection() {
                Task { @MainActor in
                    if let activeConnection = self.activeConnection {
                        continuation.resume(returning: activeConnection)
                    } else if Date() >= deadline {
                        continuation.resume(returning: nil)
                    } else {
                        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                            checkConnection()
                        }
                    }
                }
            }

            checkConnection()
        }
    }

    public func restartTracking() {
        Task { await attemptConnection() }
    }

    private func checkActiveConnection() async {
        guard let activeConnection else {
            os_log("No active connection, attempting to reconnect...", log: OSLog.default, type: .info)
            await attemptConnection()
            return
        }

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

        let sortedConfigs = connectionConfigurations.sorted { $0.priority < $1.priority }
        var bestConnection: ConnectionInfo?
        var connectedCounts = 0

        await withTaskGroup(of: ConnectionInfo?.self) { group in
            for config in sortedConfigs {
                group.addTask {
                    await self.testConnection(configuration: config)
                }
            }

            for await connectionInfo in group {
                guard let connectionInfo else { continue }
                if connectionInfo.configuration.priority == 0 {
                    await setActiveConnection(connectionInfo)
                    return
                }
                if bestConnection == nil || connectionInfo.configuration.priority < bestConnection!.configuration.priority {
                    bestConnection = connectionInfo
                }
            }
        }

        await setActiveConnection(bestConnection)
    }

    private func testConnection(configuration: ConnectionConfiguration) async -> ConnectionInfo? {
        guard URL(string: configuration.url) != nil else { return nil }

        do {
            let version = try await connectionPool.getOrCreateService(for: configuration).getRootVersion()
            let connectionInfo = ConnectionInfo(configuration: configuration, version: version)
            logger.info("Successfully connected to \(configuration.url)")
            return connectionInfo
        } catch NetworkTrackerError.invalidServerVersion {
            logger.info("Invalid server version from \(configuration.url)")
            return nil
        } catch {
            logger.info("Failed to connect to \(configuration.url)")
            return nil
        }
    }

    private func startRetryTask(_ retryInterval: UInt64) {
        retryTask?.cancel()
        retryTask = Task {
            let retryInterval = retryInterval * 1_000_000_000
            try? await Task.sleep(nanoseconds: retryInterval)
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

    @MainActor
    private func setActiveConnection(_ connection: ConnectionInfo?) async {
        guard activeConnection != connection else { return }

        activeConnection = connection
        if let connection {
            status = .connected
        } else {
            status = .notConnected
            startRetryTask(disconnectedRetryInterval)
        }
    }

    // Ensures that all URLs pointing to "myopenhab.org" are standardized to "home.myopenhab.org".
    private func adjustMyOpenHABHosts(in configurations: [ConnectionConfiguration]) -> [ConnectionConfiguration] {
        configurations.map { configuration in
            var updatedURL = configuration.url
            if let urlComponents = URLComponents(string: configuration.url),
               let host = urlComponents.host,
               host.contains("myopenhab.org"),
               host != "home.myopenhab.org" {
                var newComponents = urlComponents
                newComponents.host = "home.myopenhab.org"
                updatedURL = newComponents.url?.absoluteString ?? configuration.url
            }
            return ConnectionConfiguration(url: updatedURL, priority: configuration.priority)
        }
    }
}

public extension NetworkTracker {
    func send(to item: OpenHABItem, command: String) async {
        if let activeConnection = await NetworkTracker.shared.waitForActiveConnection() {
            let configuration = activeConnection.configuration
            let service = await connectionPool.getOrCreateService(for: configuration)
            try? await service.sendItemCommand(itemname: item.name, command: command)
        }
    }

    func updateState(for item: OpenHABItem, state: String) async {
        if let activeConnection = await NetworkTracker.shared.waitForActiveConnection() {
            let configuration = activeConnection.configuration
            let service = await connectionPool.getOrCreateService(for: configuration)
            try? await service.updateItemState(itemname: item.name, with: state)
        }
    }

    func getItems() async throws -> [OpenHABItem] {
        if let activeConnection = await NetworkTracker.shared.waitForActiveConnection() {
            let configuration = activeConnection.configuration
            let service = await connectionPool.getOrCreateService(for: configuration)
            return try await service.getItems()
        } else {
            return []
        }
    }

    func pollDataForPage(sitemapname: String, longPolling: Bool = false) async throws -> OpenHABPage? {
        if let activeConnection = await NetworkTracker.shared.waitForActiveConnection() {
            let configuration = activeConnection.configuration
            let service = await connectionPool.getOrCreateService(for: configuration)
            return try await service.pollDataForPage(sitemapname: sitemapname, longPolling: longPolling)
        } else {
            return nil
        }
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
