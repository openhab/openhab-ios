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
    case notConnected = "Not Connected"
    case connecting = "Connecting"
    case connected = "Connected"
}

public struct ConnectionConfiguration: Equatable {
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

    var debugDescription: String {
        switch self {
        case .invalidServerVersion:
            "Invalid server version"
        }
    }
}

public final class NetworkTracker: ObservableObject {
    public static let shared = NetworkTracker()

    @Published public private(set) var activeConnection: ConnectionInfo?
    @Published public private(set) var status: NetworkStatus = .connecting
    public private(set) var openApiService: OpenAPIService?

    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue.global(qos: .background)
    private var priorityWorkItem: DispatchWorkItem?
    private var connectionConfigurations: [ConnectionConfiguration] = []
    private var retryTimer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "org.openhab.networktracker.timerQueue")
    private let connectedRetryInterval: TimeInterval = 60 // amount of time we scan for better connections when connected
    private let disconnectedRetryInterval: TimeInterval = 30 // amount of time we scan when not connected

    let logger = Logger(subsystem: "org.openhab.core", category: "NetworkTracker")

    private init() {
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard self?.openApiService != nil else { return }
            if path.status == .satisfied {
                os_log("Network status: Connected", log: OSLog.default, type: .info)
                self?.checkActiveConnection()
            } else {
                os_log("Network status: Disconnected", log: OSLog.default, type: .info)
                self?.setActiveConnection(nil)
                self?.startRetryTimer(10) // try every 10 seconds connect
            }
        }
        monitor.start(queue: monitorQueue)
    }

    public func startTracking(connectionConfigurations: [ConnectionConfiguration], username: String, password: String, alwaysSendBasicAuth: Bool, ignoreSSLVerification: Bool) {
        os_log("StartTracking", log: OSLog.default, type: .info)
        self.connectionConfigurations = adjustMyOpenHABHosts(in: connectionConfigurations)
        Task {
            openApiService = await OpenAPIService(username: username, password: password, alwaysSendBasicAuth: alwaysSendBasicAuth, ignoreSSL: ignoreSSLVerification)
        }
        setActiveConnection(nil)
        attemptConnection()
    }

    @discardableResult
    public func waitForActiveConnection(
        perform action: @escaping (ConnectionInfo?) -> Void
    ) -> AnyCancellable {
        os_log("WaitForActiveConnection", log: OSLog.default, type: .info)

        return $activeConnection
            .filter { $0 != nil } // Only proceed if activeConnection is not nil
            .first() // Automatically cancels after the first non-nil value
            .receive(on: DispatchQueue.main)
            .sink { activeConnection in
                action(activeConnection)
            }
    }

    public func restartTracking() {
        attemptConnection()
    }

    // This gets called periodically when we have an active connection to make sure it's still the best choice
    private func checkActiveConnection() {
        guard let activeConnection else {
            // No active connection, proceed with the normal connection attempt
            os_log("CheckActiveConnection attemptConnection", log: OSLog.default, type: .info)
            attemptConnection()
            return
        }

        // Check if the active connection is reachable
        if let url = URL(string: activeConnection.configuration.url) {
            os_log("checkActiveConnection trying %{PUBLIC}@", log: OSLog.default, type: .info, url.absoluteString)

            Task {
                do {
                    try await openApiService?.getRoot()
                    logger.info("Network status: Active connection is reachable: \(activeConnection.configuration.url)")
                } catch {
                    logger.error("Network status: Active connection is not reachable:  \(activeConnection.configuration.url)  \(error.localizedDescription)")
                    self.attemptConnection() // If not reachable, run the connection logic
                }
            }
        }
    }

    private func attemptConnection() {
        guard !connectionConfigurations.isEmpty else {
            os_log("Network status: No connection configurations available.", log: OSLog.default, type: .error)
            setActiveConnection(nil)
            return
        }
        priorityWorkItem?.cancel()
        os_log("Network status: Checking available connections....", log: OSLog.default, type: .info)
        let dispatchGroup = DispatchGroup()
        var highestPriorityConnection: ConnectionInfo?
        var firstAvailableConnection: ConnectionInfo?
        var checkOutstanding = false // Track if there are any checks still in progress

        let priorityWaitTime: TimeInterval = 2.0

        // Set up the work item to handle the 2-second timeout
        priorityWorkItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // After 2 seconds, if no high-priority connection was found, check for first available connection
            if let firstAvailableConnection, highestPriorityConnection == nil {
                setActiveConnection(firstAvailableConnection)
            } else if highestPriorityConnection == nil, checkOutstanding {
                os_log("Network status: No connection responded in 2 seconds, waiting for checks to finish.", log: OSLog.default, type: .info)
            } else {
                os_log("Network status: No connection responded in 2 seconds and no checks are outstanding.", log: OSLog.default, type: .error)
                setActiveConnection(nil)
            }
        }

        // Begin checking each connection configuration in parallel
        for configuration in connectionConfigurations {
            dispatchGroup.enter()
            checkOutstanding = true // Signal that checks are outstanding
            os_log("attemptConnection trying %{PUBLIC}@", log: OSLog.default, type: .info, configuration.url)
            if let url = URL(string: configuration.url) {
                Task {
                    defer {
                        dispatchGroup.leave() // When each check completes, this signals the group that it's done
                    }

                    do {
                        await openApiService?.updateBaseURL(with: url)
                        let serverProperties = try await openApiService?.getRoot()

                        let version = Int(serverProperties?.version ?? "0")
                        guard let version, version > 1 else { throw NetworkTrackerError.invalidServerVersion }
                        let connectionInfo = ConnectionInfo(configuration: configuration, version: version)
                        if configuration.priority == 0, highestPriorityConnection == nil {
                            // Found a high-priority (0) connection
                            highestPriorityConnection = connectionInfo
                            priorityWorkItem?.cancel() // Stop the 2-second wait if highest priority succeeds
                            setActiveConnection(connectionInfo)
                        } else if highestPriorityConnection == nil {
                            // Check if this connection has a higher priority than the current firstAvailableConnection
                            let connectionInfo = ConnectionInfo(configuration: configuration, version: version)
                            if firstAvailableConnection == nil || configuration.priority < firstAvailableConnection!.configuration.priority {
                                logger.info("Found a higher priority available connection: \(configuration.url)")
                                firstAvailableConnection = connectionInfo
                            }
                        }
                    } catch let error as NetworkTrackerError {
                        logger.error("\(error.debugDescription)")
                    } catch {
                        logger.error("Failed to connect to \(configuration.url)")
                    }
                }
            }
        }

        // Start a timer that waits for 2 seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + priorityWaitTime, execute: priorityWorkItem!)

        // When all checks complete, finalize logic based on connection status
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self else { return }

            // All checks are finished here, so no outstanding checks
            checkOutstanding = false

            // If a high-priority connection was already established, we are done
            if let highestPriorityConnection {
                os_log("Network status: High-priority connection established with %{PUBLIC}@", log: OSLog.default, type: .info, highestPriorityConnection.configuration.url)
                return
            }

            // If we have an available connection and no high-priority connection, set the first available
            if let firstAvailableConnection {
                setActiveConnection(firstAvailableConnection)
                os_log("Network status: First available connection established with %{PUBLIC}@", log: OSLog.default, type: .info, firstAvailableConnection.configuration.url)
            } else {
                os_log("Network status: No connection responded, connection failed.", log: OSLog.default, type: .error)
                setActiveConnection(nil)
            }
        }
    }

    // Start the retry timer to attempt connection every N seconds
    private func startRetryTimer(_ retryInterval: TimeInterval) {
        cancelRetryTimer()
        timerQueue.sync {
            retryTimer = DispatchSource.makeTimerSource(queue: timerQueue)
            retryTimer?.schedule(deadline: .now() + retryInterval, repeating: retryInterval)
            retryTimer?.setEventHandler { [weak self] in
                os_log("Network status: Retry timer firing", log: OSLog.default, type: .info)
                self?.attemptConnection()
            }
            retryTimer?.resume()
        }
    }

    private func cancelRetryTimer() {
        timerQueue.sync {
            retryTimer?.cancel()
            retryTimer = nil
        }
    }

    private func setActiveConnection(_ connection: ConnectionInfo?) {
        os_log("Network status: setActiveConnection: %{PUBLIC}@", log: OSLog.default, type: .info, connection?.configuration.url ?? "no connection")
        guard activeConnection != connection else { return }
        activeConnection = connection
        if let activeConnection {
            updateStatus(.connected)
            Task {
                await openApiService?.updateBaseURL(with: URL(string: activeConnection.configuration.url) ?? URL(staticString: "about:blank"))
            }
            // startRetryTimer(connectedRetryInterval)
        } else {
            updateStatus(.notConnected)
            startRetryTimer(disconnectedRetryInterval)
        }
    }

    private func updateStatus(_ newStatus: NetworkStatus) {
        if status != newStatus {
            status = newStatus
        }
    }

    private func adjustMyOpenHABHosts(in configurations: [ConnectionConfiguration]) -> [ConnectionConfiguration] {
        configurations.map { configuration in
            let updatedURL: String
            if let urlComponents = URLComponents(string: configuration.url),
               let host = urlComponents.host,
               host.contains("myopenhab.org"), host != "home.myopenhab.org" {
                var newComponents = urlComponents
                newComponents.host = "home.myopenhab.org"
                updatedURL = newComponents.url?.absoluteString ?? configuration.url
            } else {
                updatedURL = configuration.url
            }
            return ConnectionConfiguration(url: updatedURL, priority: configuration.priority)
        }
    }
}
