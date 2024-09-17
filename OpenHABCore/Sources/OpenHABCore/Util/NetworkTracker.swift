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

import Alamofire
import Foundation
import Network
import os.log

// TODO: these strings should reference Localizable keys
public enum NetworkStatus: String {
    case notConnected = "Not Connected"
    case connecting = "Connecting"
    case connected = "Connected"
}

// Anticipating supporting more robust configuration options where we allow multiple url/user/pass options for users
public struct ConnectionObject: Equatable {
    public let url: String
    public let priority: Int // Lower is higher priority, 0 is primary

    public init(url: String, priority: Int = 10) {
        self.url = url
        self.priority = priority
    }

    public static func == (lhs: ConnectionObject, rhs: ConnectionObject) -> Bool {
        lhs.url == rhs.url && lhs.priority == rhs.priority
    }
}

public final class NetworkTracker: ObservableObject {
    public static let shared = NetworkTracker()

    @Published public private(set) var activeServer: ConnectionObject?
    @Published public private(set) var status: NetworkStatus = .connecting

    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue.global(qos: .background)
    private var connectionObjects: [ConnectionObject] = []

    private var retryTimer: DispatchSourceTimer?

    private init() {
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                os_log("Network status: Connected", log: OSLog.default, type: .info)
                self?.checkActiveServer()
            } else {
                os_log("Network status: Disconnected", log: OSLog.default, type: .info)
                self?.setActiveServer(nil)
                self?.startRetryTimer(10) // try every 10 seconds connect
            }
        }
        monitor.start(queue: monitorQueue)
    }

    public func startTracking(connectionObjects: [ConnectionObject]) {
        self.connectionObjects = connectionObjects
        attemptConnection()
    }

    // This gets called periodically when we have an active server to make sure its still the best choice
    private func checkActiveServer() {
        guard let activeServer, activeServer.priority == 0 else {
            // No primary active server, proceed with the normal connection attempt
            attemptConnection()
            return
        }
        // Check if the primary (priority = 0)  active server is reachable if thats what is currenty connected.
        NetworkConnection.tracker(openHABRootUrl: activeServer.url) { [weak self] response in
            switch response.result {
            case .success:
                os_log("Network status: Active server is reachable: %{PUBLIC}@", log: OSLog.default, type: .info, activeServer.url)
            case .failure:
                os_log("Network status: Active server is not reachable: %{PUBLIC}@", log: OSLog.default, type: .error, activeServer.url)
                self?.attemptConnection() // If not reachable, run the connection logic
            }
        }
    }

    private func attemptConnection() {
        guard !connectionObjects.isEmpty else {
            os_log("Network status: No connection objects available.", log: OSLog.default, type: .error)
            setActiveServer(nil)
            return
        }
        os_log("Network status: checking available servers....", log: OSLog.default, type: .error)
        let dispatchGroup = DispatchGroup()
        var highestPriorityConnection: ConnectionObject?
        var firstAvailableConnection: ConnectionObject?
        var checkOutstanding = false // Track if there are any checks still in progress

        let priorityWaitTime: TimeInterval = 2.0
        var priorityWorkItem: DispatchWorkItem?

        // Set up the work item to handle the 2-second timeout
        priorityWorkItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // After 2 seconds, if no high-priority connection was found, check for first available connection
            if let firstAvailableConnection, highestPriorityConnection == nil {
                setActiveServer(firstAvailableConnection)
            } else if highestPriorityConnection == nil, checkOutstanding {
                os_log("Network status: No server responded in 2 seconds, waiting for checks to finish.", log: OSLog.default, type: .info)
            } else {
                os_log("Network status: No server responded in 2 seconds and no checks are outstanding.", log: OSLog.default, type: .error)
                setActiveServer(nil)
            }
        }

        // Begin checking each connection object in parallel
        for connection in connectionObjects {
            dispatchGroup.enter()
            checkOutstanding = true // Signal that checks are outstanding

            NetworkConnection.tracker(openHABRootUrl: connection.url) { [weak self] response in
                guard let self else { return }
                defer {
                    dispatchGroup.leave() // When each check completes, this signals the group that it's done
                }

                switch response.result {
                case let .success(data):
                    let version = getServerInfoFromData(data: data)
                    if version > 0 {
                        if connection.priority == 0, highestPriorityConnection == nil {
                            // Found a high-priority (0)  connection
                            highestPriorityConnection = connection
                            priorityWorkItem?.cancel() // Stop the 2-second wait if highest priority succeeds
                            setActiveServer(connection)
                        } else if highestPriorityConnection == nil {
                            // Check if this connection has a higher priority than the current firstAvailableConnection
                            if firstAvailableConnection == nil || connection.priority < firstAvailableConnection!.priority {
                                os_log("Network status: Found a higher priority available connection: %{PUBLIC}@", log: OSLog.default, type: .info, connection.url)
                                firstAvailableConnection = connection
                            }
                        }
                    } else {
                        os_log("Network status: Invalid server version from %{PUBLIC}@", log: OSLog.default, type: .error, connection.url)
                    }
                case let .failure(error):
                    os_log("Network status: Failed to connect to %{PUBLIC}@ : %{PUBLIC}@", log: OSLog.default, type: .error, connection.url, error.localizedDescription)
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
                os_log("Network status: High-priority connection established with %{PUBLIC}@", log: OSLog.default, type: .info, highestPriorityConnection.url)
                return
            }

            // If we have an available connection and no high-priority connection, set the first available
            if let firstAvailableConnection {
                setActiveServer(firstAvailableConnection)
                os_log("Network status: First available connection established with %{PUBLIC}@", log: OSLog.default, type: .info, firstAvailableConnection.url)
            } else {
                os_log("Network status: No server responded, connection failed.", log: OSLog.default, type: .error)
                setActiveServer(nil)
            }
        }
    }

    // Start the retry timer to attempt connection every N seconds
    private func startRetryTimer(_ retryInterval: TimeInterval) {
        cancelRetryTimer()
        retryTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        retryTimer?.schedule(deadline: .now() + retryInterval, repeating: retryInterval)
        retryTimer?.setEventHandler { [weak self] in
            os_log("Network status: Retry timer firing", log: OSLog.default, type: .info)
            self?.attemptConnection()
        }
        retryTimer?.resume()
    }

    // Cancel the retry timer
    private func cancelRetryTimer() {
        retryTimer?.cancel()
        retryTimer = nil
    }

    private func setActiveServer(_ server: ConnectionObject? = nil) {
        os_log("Network status: setActiveServer: %{PUBLIC}@", log: OSLog.default, type: .info, server?.url ?? "no server")
        if activeServer != server {
            activeServer = server
            if let activeServer {
                updateStatus(.connected)
                startRetryTimer(60) // check every 60 seconds to see if a better server is available.
            } else {
                updateStatus(.notConnected)
                startRetryTimer(30) // check every 30 seconds to see if a server is available.
            }
        }
    }

    private func updateStatus(_ newStatus: NetworkStatus) {
        if status != newStatus {
            status = newStatus
        }
    }

    private func getServerInfoFromData(data: Data) -> Int {
        do {
            let serverProperties = try data.decoded(as: OpenHABServerProperties.self)
            // OH versions 2.0 through 2.4 return "1" as their version, so set the floor to 2 so we do not think this is an OH 1.x server
            return max(2, Int(serverProperties.version) ?? 2)
        } catch {
            return -1
        }
    }
}
