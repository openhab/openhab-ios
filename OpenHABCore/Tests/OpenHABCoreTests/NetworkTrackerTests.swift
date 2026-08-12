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
import OSLog

@testable import OpenHABCore
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
    var mockServerProperties = OpenHABServerProperties(version: "", links: [])
    var rootVersionDelay: Duration?
    var sendCommandCallCount: Int = 0
    var clientErrorsBeforeSuccess: Int = 0

    init(returnedVersion: Int = 123, shouldFail: Bool = false, mockServerProperties: OpenHABServerProperties = .init(version: "", links: []), rootVersionDelay: Duration? = nil, clientErrorsBeforeSuccess: Int = 0) {
        self.returnedVersion = returnedVersion
        self.shouldFail = shouldFail
        self.mockServerProperties = mockServerProperties
        self.rootVersionDelay = rootVersionDelay
        self.clientErrorsBeforeSuccess = clientErrorsBeforeSuccess
    }

    func sendItemCommand(itemname: String, command: String, sourcePrefix: String?, deviceId: String?) async throws {
        sendCommandCallCount += 1
        if sendCommandCallCount <= clientErrorsBeforeSuccess {
            throw OpenAPIRuntime.ClientError(
                operationID: "sendItemCommand",
                operationInput: "" as any Sendable,
                causeDescription: "simulated transport failure",
                underlyingError: networkTrackerError
            )
        }
        if shouldFail {
            throw networkTrackerError
        }
    }

    func updateItemState(itemname: String, with: String, sourcePrefix: String?, deviceId: String?) async throws {
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
        if let delay = rootVersionDelay {
            try await Task.sleep(for: delay)
        }
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
        let stateStream = await networkTracker.stateStream()

        let statusTask = Task {
            var receivedFirstValue = false
            for await state in stateStream {
                let status = state.status
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

    // MARK: - connecting / retry / availability (hardening) coverage

    private func makeTracker(service: MockOpenAPIService) -> NetworkTracker {
        NetworkTracker(
            monitor: MockPathMonitor(),
            connectionPool: ConnectionPool { _ in service },
            failureTracker: ConnectionFailureTracker()
        )
    }

    private var mockConfig: ConnectionConfiguration {
        ConnectionConfiguration(url: "http://mock", username: "", password: "", priority: 0)
    }

    /// The connect flow must surface the transient `.connecting` state before `.connected`.
    func testTrackerEmitsConnectingBeforeConnected() async {
        let sawConnecting = XCTestExpectation(description: "Status becomes .connecting")
        let connectedAfterConnecting = XCTestExpectation(description: "Status becomes .connected after .connecting")

        let tracker = makeTracker(service: MockOpenAPIService(returnedVersion: 8))
        let stateStream = await tracker.stateStream()

        let task = Task {
            var connectingSeen = false
            for await state in stateStream {
                if state.status == .connecting, !connectingSeen {
                    connectingSeen = true
                    sawConnecting.fulfill()
                }
                if state.status == .connected {
                    if connectingSeen { connectedAfterConnecting.fulfill() }
                    break
                }
            }
        }

        await tracker.startTracking(connectionConfigurations: [mockConfig])
        await fulfillment(of: [sawConnecting, connectedAfterConnecting], timeout: 2.0)
        task.cancel()
        await tracker.stopTracking()
    }

    /// A failed connection must publish a `nextRetryDate` so the UI can count down to the retry.
    func testTrackerPublishesRetryDeadlineWhenConnectionFails() async {
        let retryScheduled = XCTestExpectation(description: "nextRetryDate published")

        let tracker = makeTracker(service: MockOpenAPIService(returnedVersion: 8, shouldFail: true))
        let stateStream = await tracker.stateStream()

        let task = Task {
            for await state in stateStream where state.nextRetryDate != nil {
                retryScheduled.fulfill()
                break
            }
        }

        await tracker.startTracking(connectionConfigurations: [mockConfig])
        await fulfillment(of: [retryScheduled], timeout: 3.0)
        task.cancel()
        await tracker.stopTracking()
    }

    /// `stopTracking()` must reset to `.stopped` and clear the active connection and retry deadline.
    func testStopTrackingResetsToStoppedAndClearsState() async {
        let connected = XCTestExpectation(description: "Status becomes .connected")

        let tracker = makeTracker(service: MockOpenAPIService(returnedVersion: 8))
        let stateStream = await tracker.stateStream()

        let task = Task {
            for await state in stateStream where state.status == .connected {
                connected.fulfill()
                break
            }
        }

        await tracker.startTracking(connectionConfigurations: [mockConfig])
        await fulfillment(of: [connected], timeout: 2.0)
        task.cancel()

        await tracker.stopTracking()

        let status = await tracker.status
        let activeConnection = await tracker.activeConnection
        let nextRetryDate = await tracker.nextRetryDate
        XCTAssertEqual(status, .stopped)
        XCTAssertNil(activeConnection)
        XCTAssertNil(nextRetryDate)
    }

    /// A network-down event must mark the network unavailable and abandon the pending retry.
    func testNetworkLossMarksUnavailableAndAbandonsRetry() async {
        let retryScheduled = XCTestExpectation(description: "nextRetryDate published")
        retryScheduled.assertForOverFulfill = false
        let networkUnavailable = XCTestExpectation(description: "isNetworkAvailable false and retry cleared")

        let mockMonitor = MockPathMonitor()
        let tracker = NetworkTracker(
            monitor: mockMonitor,
            connectionPool: ConnectionPool { _ in MockOpenAPIService(returnedVersion: 8, shouldFail: true) },
            failureTracker: ConnectionFailureTracker()
        )
        let stateStream = await tracker.stateStream()

        let task = Task {
            for await state in stateStream {
                if state.nextRetryDate != nil { retryScheduled.fulfill() }
                if !state.isNetworkAvailable, state.nextRetryDate == nil {
                    networkUnavailable.fulfill()
                    break
                }
            }
        }

        await tracker.startTracking(connectionConfigurations: [mockConfig])
        // The failing connection schedules a retry (sets nextRetryDate).
        await fulfillment(of: [retryScheduled], timeout: 3.0)

        // Once the path monitor is active, a network-down event must abandon that retry.
        await mockMonitor.waitForMonitoringToStart()
        await mockMonitor.simulateConnection(isConnected: false)

        await fulfillment(of: [networkUnavailable], timeout: 3.0)
        task.cancel()
        await tracker.stopTracking()
    }

    /// When a preferred connection is slow, the fallback must become active before the preferred times out.
    /// Ported from develop commit 06f0bf1c, re-expressed against stateStream() instead of statusStream().
    func testFallbackConnectionBecomesActiveBeforePreferredConnectionTimesOut() async {
        let fallbackBecameActive = XCTestExpectation(description: "Fallback connection is active")

        let preferredConfig = ConnectionConfiguration(url: "http://preferred", username: "", password: "", priority: 0)
        let fallbackConfig = ConnectionConfiguration(url: "http://fallback", username: "", password: "", priority: 10)

        let slowService = MockOpenAPIService(returnedVersion: 8, rootVersionDelay: .seconds(5))
        let fastService = MockOpenAPIService(returnedVersion: 8)

        let pool = ConnectionPool { config in
            config.url == "http://preferred" ? slowService : fastService
        }
        let mockMonitor = MockPathMonitor()
        let tracker = NetworkTracker(
            monitor: mockMonitor,
            connectionPool: pool,
            failureTracker: ConnectionFailureTracker()
        )
        let stateStream = await tracker.stateStream()

        let task = Task {
            for await state in stateStream {
                if state.activeConnection?.configuration.url == "http://fallback" {
                    fallbackBecameActive.fulfill()
                    break
                }
            }
        }

        let monitoringTask = Task { await mockMonitor.waitForMonitoringToStart() }
        await tracker.startTracking(connectionConfigurations: [preferredConfig, fallbackConfig])
        await monitoringTask.value
        await mockMonitor.simulateConnection(isConnected: true)

        // Fallback must win within the grace window (1s) plus some headroom — well before the 5-second preferred delay.
        await fulfillment(of: [fallbackBecameActive], timeout: 3.0)
        task.cancel()
        await tracker.stopTracking()
    }

    /// A transient ClientError must trigger revalidateConnection() and one retry; the overall call succeeds.
    /// Covers the withClientErrorRetry/revalidateConnection resilience ported in develop commit 9de4e7f0.
    func testClientErrorTriggersRevalidateAndRetry() async throws {
        let connected = XCTestExpectation(description: "Status becomes .connected")

        let service = MockOpenAPIService(returnedVersion: 8, clientErrorsBeforeSuccess: 1)
        let mockMonitor = MockPathMonitor()
        let tracker = NetworkTracker(
            monitor: mockMonitor,
            connectionPool: ConnectionPool { _ in service },
            failureTracker: ConnectionFailureTracker()
        )
        let stateStream = await tracker.stateStream()

        let task = Task {
            for await state in stateStream where state.status == .connected {
                connected.fulfill()
                break
            }
        }

        let monitoringTask = Task { await mockMonitor.waitForMonitoringToStart() }
        await tracker.startTracking(connectionConfigurations: [mockConfig])
        await monitoringTask.value
        await mockMonitor.simulateConnection(isConnected: true)
        await fulfillment(of: [connected], timeout: 2.0)
        task.cancel()

        // First sendItemCommand throws ClientError → revalidateConnection() → retry succeeds.
        try await tracker.send(to: "TestItem", command: "ON", deviceId: nil)

        let callCount = await service.sendCommandCallCount
        XCTAssertEqual(callCount, 2, "Expected 1 failed attempt + 1 successful retry")
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
