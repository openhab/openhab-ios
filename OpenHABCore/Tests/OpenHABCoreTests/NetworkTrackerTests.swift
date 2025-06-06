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

@testable import OpenHABCore
import XCTest

final actor MockOpenAPIService: OpenAPIServiceProtocol {
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
            throw NetworkTrackerError.failedConnection("http://mock")
        }
    }

    func updateItemState(itemname: String, with: String) async throws {
        if shouldFail {
            throw NetworkTrackerError.failedConnection("http://mock")
        }
    }

    func getItems() async throws -> [OpenHABCore.OpenHABItem] {
        if shouldFail {
            throw NetworkTrackerError.failedConnection("http://mock")
        }
        return []
    }

    func getItemByName(id: String) async throws -> OpenHABCore.OpenHABItem? {
        if shouldFail {
            throw NetworkTrackerError.failedConnection("http://mock")
        }
        return nil
    }

    func pollDataForPage(sitemapname: String, pageId: String, longPolling: Bool) async throws -> OpenHABCore.OpenHABPage? {
        if shouldFail {
            throw NetworkTrackerError.failedConnection("http://mock")
        }
        return nil
    }

    func runNow(ruleUID: String, payload: [String: any Sendable]) async throws {
        if shouldFail {
            throw NetworkTrackerError.failedConnection("http://mock")
        }
    }

    func getRootVersion() async throws -> Int {
        if shouldFail {
            throw NetworkTrackerError.failedConnection("http://mock")
        }
        return returnedVersion
    }

    @discardableResult
    func getRoot() async throws -> OpenHABServerProperties {
        if shouldFail {
            throw NetworkTrackerError.failedConnection("http://mock")
        }
        return mockServerProperties
    }
}

final class MockPathMonitor: NWPathMonitoring {
    func cancel() {
        // no-op
    }

    private var handler: ((Bool) async -> Void)?
    private var simulateConnectionContinuation: CheckedContinuation<Void, Never>?

    func startMonitoring(handler: @escaping (Bool) async -> Void) async {
        self.handler = handler
    }

    func simulateConnection(isConnected: Bool) async {
        guard let handler else { return }
        await handler(isConnected)
        simulateConnectionContinuation?.resume()
    }

    func waitUntilSimulatedConnectionHandled() async {
        await withCheckedContinuation { continuation in
            simulateConnectionContinuation = continuation
        }
    }
}

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

        let tracker = NetworkTracker(
            monitor: mockMonitor,
            connectionPool: mockPool,
            failureTracker: ConnectionFailureTracker()
        )

        var cancellables = Set<AnyCancellable>()

        tracker.$status
            .dropFirst() // skip initial `.connecting`
            .sink { status in
                if status == .connected {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Start tracking with your mock config
        await tracker.startTracking(connectionConfigurations: [config])

        // Simulate the network becoming available
        await mockMonitor.simulateConnection(isConnected: true)

        await fulfillment(of: [expectation], timeout: 2.0)
    }

    @MainActor
    func testTrackerGoesOfflineOnNetworkLoss() async {
        let becameNotConnected = XCTestExpectation(description: "Status becomes .notConnected")

        let mockMonitor = MockPathMonitor()
        let tracker = NetworkTracker(
            monitor: mockMonitor,
            connectionPool: ConnectionPool { _ in MockOpenAPIService() },
            failureTracker: ConnectionFailureTracker()
        )

        var cancellables = Set<AnyCancellable>()

        tracker.$status
            .dropFirst()
            .sink { status in
                if status == .notConnected {
                    becameNotConnected.fulfill()
                }
            }
            .store(in: &cancellables)

        await tracker.startTracking(connectionConfigurations: [
            ConnectionConfiguration(url: "http://mock", username: "", password: "", priority: 0)
        ])

        await mockMonitor.simulateConnection(isConnected: false)
        await mockMonitor.waitUntilSimulatedConnectionHandled()

        await fulfillment(of: [becameNotConnected], timeout: 2.0)
    }
}
