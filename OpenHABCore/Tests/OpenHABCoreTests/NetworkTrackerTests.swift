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
@testable import OpenHABCore
import OSLog
import Testing
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
    var rootVersionDelay: Duration?
    var mockServerProperties = OpenHABServerProperties(version: "", links: [])

    init(returnedVersion: Int = 123,
         shouldFail: Bool = false,
         rootVersionDelay: Duration? = nil,
         mockServerProperties: OpenHABServerProperties = .init(version: "", links: [])) {
        self.returnedVersion = returnedVersion
        self.shouldFail = shouldFail
        self.rootVersionDelay = rootVersionDelay
        self.mockServerProperties = mockServerProperties
    }

    func sendItemCommand(itemname: String, command: String, sourcePrefix: String?, deviceId: String?) throws {
        if shouldFail {
            throw networkTrackerError
        }
    }

    func updateItemState(itemname: String, with: String, sourcePrefix: String?, deviceId: String?) throws {
        if shouldFail {
            throw networkTrackerError
        }
    }

    func getItems(query: OpenHABCore.Operations.getItems.Input.Query) throws -> [OpenHABCore.OpenHABItem] {
        try getItems()
    }

    func getItems() throws -> [OpenHABCore.OpenHABItem] {
        if shouldFail {
            throw networkTrackerError
        }
        return []
    }

    func getItemByName(id: String) throws -> OpenHABCore.OpenHABItem? {
        if shouldFail {
            throw networkTrackerError
        }
        return nil
    }

    func pollDataForPage(sitemapname: String, pageId: String, longPolling: Bool) throws -> OpenHABCore.OpenHABPage? {
        if shouldFail {
            throw networkTrackerError
        }
        return nil
    }

    func runNow(ruleUID: String, payload: [String: any Sendable]) throws {
        if shouldFail {
            throw networkTrackerError
        }
    }

    func getRootVersion() async throws -> Int {
        if let rootVersionDelay {
            try await Task.sleep(for: rootVersionDelay)
        }
        if shouldFail {
            throw networkTrackerError
        }
        return returnedVersion
    }

    @discardableResult
    func getRoot() throws -> OpenHABServerProperties {
        if shouldFail {
            throw networkTrackerError
        }
        return mockServerProperties
    }

    // swiftlint:disable async_without_await
    func openHABcreateSubscription() async throws -> String? { nil }

    func openHABSitemapWidgetEvents(subscriptionid: String, sitemap: String, pageId: String)
        async throws -> any AsyncSequence<SitemapEventMessage, any Error> & Sendable {
        AsyncThrowingStream<SitemapEventMessage, any Error> { $0.finish() }
    }

    func openHABEvents(topics: String?) async throws -> any AsyncSequence<OpenHABEvent, any Error> & Sendable {
        AsyncThrowingStream<OpenHABEvent, any Error> { $0.finish() }
    }
    // swiftlint:enable async_without_await
}

actor PathMonitor {
    var handler: ((Bool) -> Void)?
    private var monitoringStarted = false
    private var waitingContinuations: [CheckedContinuation<Void, Never>] = []

    func connectionUpdates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            handler = { connectionStatus in
                continuation.yield(connectionStatus)
            }
        }
    }

    func signalMonitoringStarted() {
        monitoringStarted = true
        // Resume all waiting continuations
        for continuation in waitingContinuations {
            continuation.resume()
        }
        waitingContinuations.removeAll()
    }

    func waitForMonitoringStarted() async {
        if monitoringStarted {
            return
        }
        await withCheckedContinuation { continuation in
            waitingContinuations.append(continuation)
        }
    }

    func changeState(_ state: Bool) {
        handler?(state)
    }
}

final class MockPathMonitor: NWPathMonitoring, @unchecked Sendable {
    private let monitor: PathMonitor = .init()

    func startMonitoring(handler: @escaping (Bool) async -> Void) async {
        // Signal that monitoring has started before entering the loop
        await monitor.signalMonitoringStarted()

        for await connected in await monitor.connectionUpdates() {
            await handler(connected)
        }
    }

    func cancel() {
        // no-op
    }

    /// Waits until startMonitoring has been called
    func waitForMonitoringToStart() async {
        await monitor.waitForMonitoringStarted()
    }

    /// Call this in your tests to simulate a connection status change
    func simulateConnection(isConnected: Bool) async {
        await monitor.changeState(isConnected)
    }
}

// MARK: - connectionConfiguration(forHost:) Tests

private let localConfig = ConnectionConfiguration(
    url: "https://local.openhab.org",
    username: "localuser",
    password: "localpass",
    priority: 0
)

private let remoteConfig = ConnectionConfiguration(
    url: "https://remote.openhab.org",
    username: "remoteuser",
    password: "remotepass",
    priority: 10
)

private let proxyURL = URL(string: "https://proxy.openhab.org")!

@Suite("NetworkTracker.connectionConfiguration(forHost:)")
struct ConnectionConfigurationForHostTests {
    @Test("Returns active connection configuration when host matches active connection URL")
    func matchesActiveConnectionHost() async {
        let tracker = NetworkTracker()
        let connection = ConnectionInfo(configuration: localConfig, version: 1)
        await tracker.setMockConnection(connection)
        await tracker.setMockConnectionConfigurations([localConfig, remoteConfig])

        let result = await tracker.connectionConfiguration(forHost: "local.openhab.org")
        #expect(result == localConfig)
    }

    @Test("Returns active connection configuration when host matches proxy URL")
    func matchesProxyHost() async {
        let tracker = NetworkTracker()
        let connection = ConnectionInfo(configuration: remoteConfig, version: 1, proxyURL: proxyURL)
        await tracker.setMockConnection(connection)
        await tracker.setMockConnectionConfigurations([remoteConfig])

        let result = await tracker.connectionConfiguration(forHost: "proxy.openhab.org")
        #expect(result == remoteConfig)
    }

    @Test("Falls back to configured connections when active connection does not match")
    func fallsBackToConfiguredConnections() async {
        let tracker = NetworkTracker()
        let connection = ConnectionInfo(configuration: localConfig, version: 1)
        await tracker.setMockConnection(connection)
        await tracker.setMockConnectionConfigurations([localConfig, remoteConfig])

        let result = await tracker.connectionConfiguration(forHost: "remote.openhab.org")
        #expect(result == remoteConfig)
    }

    @Test("Returns nil when no configuration matches")
    func returnsNilForUnknownHost() async {
        let tracker = NetworkTracker()
        let connection = ConnectionInfo(configuration: localConfig, version: 1)
        await tracker.setMockConnection(connection)
        await tracker.setMockConnectionConfigurations([localConfig, remoteConfig])

        let result = await tracker.connectionConfiguration(forHost: "unknown.example.com")
        #expect(result == nil)
    }

    @Test("Returns matching configured connection when there is no active connection")
    func matchesWithoutActiveConnection() async {
        let tracker = NetworkTracker()
        await tracker.setMockConnectionConfigurations([localConfig, remoteConfig])

        let result = await tracker.connectionConfiguration(forHost: "remote.openhab.org")
        #expect(result == remoteConfig)
    }

    @Test("Returns nil when there are no configured connections and no active connection")
    func returnsNilWhenEmpty() async {
        let tracker = NetworkTracker()

        let result = await tracker.connectionConfiguration(forHost: "local.openhab.org")
        #expect(result == nil)
    }

    @Test("Active connection takes priority over same-host configured connection")
    func activeConnectionPrioritisedOverConfigured() async {
        let tracker = NetworkTracker()
        let activeConfig = ConnectionConfiguration(
            url: "https://local.openhab.org",
            username: "activeuser",
            password: "activepass",
            priority: 5
        )
        let connection = ConnectionInfo(configuration: activeConfig, version: 1)
        await tracker.setMockConnection(connection)
        await tracker.setMockConnectionConfigurations([localConfig, remoteConfig])

        let result = await tracker.connectionConfiguration(forHost: "local.openhab.org")
        #expect(result == activeConfig)
        #expect(result?.username == "activeuser")
    }
}

@MainActor
final class NetworkTrackerTests: XCTestCase {
    func testTrackerSetsConnectedStatusOnNetworkUp() async {
        let streamIterating = XCTestExpectation(description: "Stream iteration started")
        let connectedExpectation = XCTestExpectation(description: "Status becomes .connected")
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

        // Create stream first to ensure Combine sink is attached before tracking starts
        let statusStream = await networkTracker.statusStream()

        let statusTask = Task {
            var receivedFirstValue = false
            for await status in statusStream {
                if !receivedFirstValue {
                    receivedFirstValue = true
                    streamIterating.fulfill()
                }
                Logger.testNetworkTracker
                    .info("NetworkTrackerTests: Network status became \(status == .connected ? "connected" : (status == .connecting ? "connecting" : (status == .started ? "started" : "stopped")))")
                if status == .connected {
                    connectedExpectation.fulfill()
                    break
                }
            }
        }

        // Wait for the stream to actually start iterating before triggering any state changes
        await fulfillment(of: [streamIterating], timeout: 1.0)

        // Start a task to wait for monitoring to begin
        let monitoringTask = Task {
            await mockMonitor.waitForMonitoringToStart()
        }

        // Start tracking with your mock config
        await networkTracker.startTracking(connectionConfigurations: [config])

        // Wait for path monitor's startMonitoring to be called before simulating connection
        await monitoringTask.value

        // Simulate the network becoming available
        await mockMonitor.simulateConnection(isConnected: true)

        await fulfillment(of: [connectedExpectation], timeout: 2.0)
        statusTask.cancel()
    }

    func testFallbackConnectionBecomesActiveBeforePreferredConnectionTimesOut() async {
        let localConfig = ConnectionConfiguration(
            url: "http://local",
            username: "",
            password: "",
            priority: 0
        )
        let remoteConfig = ConnectionConfiguration(
            url: "https://remote",
            username: "",
            password: "",
            priority: 1
        )

        let localService = MockOpenAPIService(shouldFail: true, rootVersionDelay: .seconds(5))
        let remoteService = MockOpenAPIService(returnedVersion: 8)
        let mockPool = ConnectionPool { configuration in
            if configuration == localConfig {
                return localService
            }
            return remoteService
        }
        let mockMonitor = MockPathMonitor()
        let networkTracker = NetworkTracker(
            monitor: mockMonitor,
            connectionPool: mockPool,
            failureTracker: ConnectionFailureTracker(),
            timeout: 5
        )

        let startedAt = Date()
        await networkTracker.startTracking(connectionConfigurations: [localConfig, remoteConfig])

        let activeConnection = await networkTracker.waitForActiveConnection()
        let elapsed = Date().timeIntervalSince(startedAt)

        #expect(activeConnection?.configuration == remoteConfig)
        #expect(elapsed < 2.5)
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
