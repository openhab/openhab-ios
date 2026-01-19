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
import OSLog

@testable import OpenHABCore
import XCTest

final actor MockOpenAPIService: OpenAPIServiceProtocol {
    final class MockError: Error {
        var debugDescription: String {
            "MockConnectionFailure"
        }
    }

    let networkTrackerError = MockError()

    var shouldFail = false
    var returnedVersion = 123
    var mockServerProperties = OpenHABServerProperties(version: "", links: [])

    init(returnedVersion: Int = 123, shouldFail: Bool = false, mockServerProperties: OpenHABServerProperties = .init(version: "", links: [])) {
        self.returnedVersion = returnedVersion
        self.shouldFail = shouldFail
        self.mockServerProperties = mockServerProperties
    }

    func sendItemCommand(itemname: String, command: String) async throws {
        if shouldFail {
            throw networkTrackerError
        }
    }

    func updateItemState(itemname: String, with: String) async throws {
        if shouldFail {
            throw networkTrackerError
        }
    }

    func getItems(query: OpenHABCore.Operations.getItems.Input.Query) async throws -> [OpenHABCore.OpenHABItem] {
        try await getItems()
    }

    func getItems() async throws -> [OpenHABCore.OpenHABItem] {
        if shouldFail {
            throw networkTrackerError
        }
        return []
    }

    func getItemByName(id: String) async throws -> OpenHABCore.OpenHABItem? {
        if shouldFail {
            throw networkTrackerError
        }
        return nil
    }

    func pollDataForPage(sitemapname: String, pageId: String, longPolling: Bool) async throws -> OpenHABCore.OpenHABPage? {
        if shouldFail {
            throw networkTrackerError
        }
        return nil
    }

    func runNow(ruleUID: String, payload: [String: any Sendable]) async throws {
        if shouldFail {
            throw networkTrackerError
        }
    }

    func getRootVersion() async throws -> Int {
        if shouldFail {
            throw networkTrackerError
        }
        return returnedVersion
    }

    @discardableResult
    func getRoot() async throws -> OpenHABServerProperties {
        if shouldFail {
            throw networkTrackerError
        }
        return mockServerProperties
    }
}

actor PathMonitor {
    var handler: ((Bool) -> Void)?
    func connectionUpdates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            handler = { connectionStatus in
                continuation.yield(connectionStatus)
            }
        }
    }

    func changeState(_ state: Bool) {
        handler?(state)
    }
}

final class MockPathMonitor: NWPathMonitoring {
    private let monitor: PathMonitor = .init()

    func startMonitoring(handler: @escaping (Bool) async -> Void) async {
        for await connected in await monitor.connectionUpdates() {
            await handler(connected)
        }
    }

    func cancel() {
        // no-op
    }

    /// Call this in your tests to simulate a connection status change
    func simulateConnection(isConnected: Bool) {
        let monitor = monitor
        Task.detached {
            await monitor.changeState(isConnected)
        }
    }
}

@MainActor
final class NetworkTrackerTests: XCTestCase {
    func testTrackerSetsConnectedStatusOnNetworkUp() async {
        let expectation = XCTestExpectation(description: "Status becomes .connected")
        let config = ConnectionConfiguration(
            url: "http://mock",
            username: "",
            password: "",
            priority: 0
        )

        // Inject mock service
        let mockService = MockOpenAPIService(returnedVersion: 8)

        let mockPool = ConnectionPool { _ in mockService }
        let mockMonitor = MockPathMonitor()

        let networkTracker = NetworkTracker(
            monitor: mockMonitor,
            connectionPool: mockPool,
            failureTracker: ConnectionFailureTracker()
        )

        // Get the status stream first to ensure subscription is established before tracking starts
        let statusStream = await networkTracker.statusStream()

        let statusTask = Task {
            for await status in statusStream {
                Logger.testNetworkTracker
                    .info("NetworkTrackerTests: Network status became \(status == .connected ? "connected" : (status == .connecting ? "connecting" : (status == .started ? "started" : "stopped")))")
                if status == .connected {
                    expectation.fulfill()
                    break
                }
            }
        }

        // Start tracking with your mock config
        await networkTracker.startTracking(connectionConfigurations: [config])

        // Simulate the network becoming available
        mockMonitor.simulateConnection(isConnected: true)

        await fulfillment(of: [expectation], timeout: 2.0)
        statusTask.cancel()
    }

//    @MainActor
//    func testTrackerGoesOfflineOnNetworkLoss() async {
//        let statusSinkAttached = XCTestExpectation(description: "Combine sink attached")
//        let becameNotConnected = XCTestExpectation(description: "Status becomes .notConnected")
//        let monitorStarted = XCTestExpectation(description: "Path monitor started")
//
//        let mockMonitor = MockPathMonitor { monitorStarted.fulfill() } // ⬅️ Hold on to this
//        let tracker = NetworkTracker(
//            monitor: mockMonitor,
//            connectionPool: ConnectionPool { _ in MockOpenAPIService() },
//            failureTracker: ConnectionFailureTracker()
//        )
//
//        var cancellables = Set<AnyCancellable>()
//
//        tracker.$status
//            .handleEvents { _ in
//                statusSinkAttached.fulfill()
//            } receiveRequest: { _ in
//            }
//            .dropFirst()
//            .sink { status in
//                if status == .notConnected {
//                    becameNotConnected.fulfill()
//                }
//            }
//            .store(in: &cancellables)
//
//        // Start tracking first to initialize properly
//        await tracker.startTracking(connectionConfigurations: [
//            ConnectionConfiguration(url: "http://mock", username: "", password: "", priority: 0)
//        ])
//
//        // 🚦 Wait until Combine and monitoring are ready before triggering anything
//        await fulfillment(of: [statusSinkAttached, monitorStarted], timeout: 2.0)
//
//        // Simulate loss of network
//        mockMonitor.simulateConnection(isConnected: false) // ✅ use directly
//
//        await fulfillment(of: [becameNotConnected], timeout: 4.0)
//    }
}
