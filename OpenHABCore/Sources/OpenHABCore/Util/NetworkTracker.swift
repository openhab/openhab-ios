// Copyright (c) 2010-2024 Contributors to the openHAB project
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

public final class NetworkTracker: ObservableObject {
    public static let shared = NetworkTracker()

    @Published public private(set) var activeConnection: ConnectionInfo?
    @Published public private(set) var status: NetworkStatus = .connecting

    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue.global(qos: .background)
    private var priorityWorkItem: DispatchWorkItem?
    private var connectionConfigurations: [ConnectionConfiguration] = []
    private var httpClient: HTTPClient?
    private var retryTimer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.openhab.networktracker.timerQueue")

    private let connectedRetryInterval: TimeInterval = 60 // amount of time we scan for better connections when connected
    private let disconnectedRetryInterval: TimeInterval = 30 // amount of time we scan when not connected

    private init() {
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
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

    public func startTracking(connectionConfigurations: [ConnectionConfiguration], username: String, password: String, alwaysSendBasicAuth: Bool) {
        self.connectionConfigurations = connectionConfigurations
        httpClient = HTTPClient(username: username, password: password, alwaysSendBasicAuth: alwaysSendBasicAuth)
        attemptConnection()
    }

    public func waitForActiveConnection(
        perform action: @escaping (ConnectionInfo?) -> Void
    ) -> AnyCancellable {
        $activeConnection
            .filter { $0 != nil } // Only proceed if activeConnection is not nil
            .first() // Automatically cancels after the first non-nil value
            .receive(on: DispatchQueue.main)
            .sink { activeConnection in
                action(activeConnection)
            }
    }

    // This gets called periodically when we have an active connection to make sure it's still the best choice
    private func checkActiveConnection() {
        guard let activeConnection else {
            // No active connection, proceed with the normal connection attempt
            attemptConnection()
            return
        }

        // Check if the active connection is reachable
        if let url = URL(string: activeConnection.configuration.url) {
            httpClient?.getServerProperties(baseURL: url) { [weak self] _, error in
                if let error {
                    os_log("Network status: Active connection is not reachable: %{PUBLIC}@ %{PUBLIC}@", log: OSLog.default, type: .error, activeConnection.configuration.url, error.localizedDescription)
                    self?.attemptConnection() // If not reachable, run the connection logic
                } else {
                    os_log("Network status: Active connection is reachable: %{PUBLIC}@", log: OSLog.default, type: .info, activeConnection.configuration.url)
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
            if let url = URL(string: configuration.url) {
                httpClient?.getServerProperties(baseURL: url) { [weak self] props, error in
                    guard let self else { return }
                    defer {
                        dispatchGroup.leave() // When each check completes, this signals the group that it's done
                    }
                    if let error {
                        os_log("Network status: Failed to connect to %{PUBLIC}@ : %{PUBLIC}@", log: OSLog.default, type: .error, configuration.url, error.localizedDescription)
                    } else {
                        let version = Int(props?.version ?? "0")
                        if let version, version > 1 {
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
                                    os_log("Network status: Found a higher priority available connection: %{PUBLIC}@", log: OSLog.default, type: .info, configuration.url)
                                    firstAvailableConnection = connectionInfo
                                }
                            }
                        } else {
                            os_log("Network status: Invalid server version from %{PUBLIC}@", log: OSLog.default, type: .error, configuration.url)
                        }
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
        if activeConnection != nil {
            updateStatus(.connected)
            startRetryTimer(connectedRetryInterval)
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
}
