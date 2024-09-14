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

// TODO: these strings should reference Localizable keys
public enum NetworkStatus: String {
    case notConnected = "Not Connected"
    case connecting
    case connected = "Connected"
    case connectionFailed = "Connection Failed"
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
    @Published public private(set) var status: NetworkStatus = .notConnected
    private var monitor: NWPathMonitor
    private var monitorQueue = DispatchQueue.global(qos: .background)
    private var connectionObjects: [ConnectionObject] = []

    private init() {
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                print("Network status: Connected")
                self?.attemptConnection()
            } else {
                print("Network status: Disconnected")
                self?.updateStatus(.notConnected)
            }
        }
        monitor.start(queue: monitorQueue)
    }

    public func startTracking(connectionObjects: [ConnectionObject]) {
        self.connectionObjects = connectionObjects
        attemptConnection()
    }

    private func checkActiveServer() {
        guard let activeServer else {
            // No active server, proceed with the normal connection attempt
            attemptConnection()
            return
        }
        // Check if the active server is reachable by making a lightweight request (e.g., a HEAD request)
        NetworkConnection.tracker(openHABRootUrl: activeServer.url) { [weak self] response in
            switch response.result {
            case .success:
                print("Network status: Active server is reachable: \(activeServer.url)")
                self?.updateStatus(.connected) // If reachable, we're done
            case .failure:
                print("Network status: Active server is not reachable: \(activeServer.url)")
                self?.attemptConnection() // If not reachable, run the connection logic
            }
        }
    }

    private func attemptConnection() {
        guard !connectionObjects.isEmpty else {
            print("Network status: No connection objects available.")
            updateStatus(.notConnected)
            return
        }

        // updateStatus(.connecting)
        let dispatchGroup = DispatchGroup()
        var highestPriorityConnection: ConnectionObject?
        var nonPriorityConnection: ConnectionObject?

        // Set the time window for priority connections (e.g., 2 seconds)
        // if a priority = 0 finishes before this time, we continue, otherwise we wait this long before picking a winner based on priority
        let priorityWaitTime: TimeInterval = 2.0
        var priorityWorkItem: DispatchWorkItem?

        for connection in connectionObjects {
            dispatchGroup.enter()
            NetworkConnection.tracker(openHABRootUrl: connection.url) { [weak self] response in
                guard let self else {
                    return
                }
                switch response.result {
                case let .success(data):
                    let version = getServerInfoFromData(data: data)
                    if version > 0 {
                        // Handle the first connection
                        if connection.priority == 0, highestPriorityConnection == nil {
                            // This is the highest priority connection
                            highestPriorityConnection = connection
                            priorityWorkItem?.cancel() // Cancel any waiting task if the highest priority connected
                            setActiveServer(connection)
                        } else if highestPriorityConnection == nil, nonPriorityConnection == nil {
                            // First non-priority connection
                            nonPriorityConnection = connection
                        }
                        dispatchGroup.leave()
                    } else {
                        print("Network status: Failed version when connecting to: \(connection.url)")
                        dispatchGroup.leave()
                    }
                case let .failure(error):
                    print("Network status: Failed connection to: \(connection.url) : \(error.localizedDescription)")
                    dispatchGroup.leave()
                }
            }
        }

        // Create a work item that waits for the priority connection
        priorityWorkItem = DispatchWorkItem { [weak self] in
            if let nonPriorityConnection, highestPriorityConnection == nil {
                // If no priority connection succeeded, use the first non-priority one
                self?.setActiveServer(nonPriorityConnection)
            }
        }

        // Wait for the priority connection for 2 seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + priorityWaitTime, execute: priorityWorkItem!)

        dispatchGroup.notify(queue: .main) {
            if let highestPriorityConnection {
                print("Network status: Highest priority connection established: \(highestPriorityConnection.url)")
            } else if let nonPriorityConnection {
                print("Network status: Non-priority connection established: \(nonPriorityConnection.url)")
            } else {
                print("Network status: No server responded.")
                self.updateStatus(.connectionFailed)
            }
        }
    }

    private func setActiveServer(_ server: ConnectionObject) {
        print("Network status: setActiveServer: \(server.url)")

        if activeServer != server {
            activeServer = server
        }
        updateStatus(.connected)
    }

    private func updateStatus(_ newStatus: NetworkStatus) {
        if status != newStatus {
            status = newStatus
        }
    }

    private func getServerInfoFromData(data: Data) -> Int {
        do {
            let serverProperties = try data.decoded(as: OpenHABServerProperties.self)
            // OH versions 2.0 through 2.4 return "1" as thier version, so set the floor to 2 so we do not think this is a OH 1.x serevr
            return max(2, Int(serverProperties.version) ?? 2)
        } catch {
            return -1
        }
    }
}
