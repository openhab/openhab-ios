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

import Foundation
import Network
import OpenAPIRuntime

@testable import OpenHABCore
import Testing

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

    // swiftlint:disable async_without_await
    func openHABcreateSubscription() async throws -> String? {
        nil
    }

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
        // Subscribe (registers PathMonitor.handler synchronously) before signaling
        // "started". Signaling first let a caller woken by waitForMonitoringToStart()
        // race ahead and call simulateConnection() while `handler` was still nil,
        // silently dropping the event — the cause of this test's intermittent failures.
        let stream = await monitor.connectionUpdates()
        await monitor.signalMonitoringStarted()

        for await connected in stream {
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

// MARK: - Shared test helpers

private let defaultMockConfig = ConnectionConfiguration(url: "http://mock", username: "", password: "", priority: 0)

private func makeTracker(service: MockOpenAPIService) -> NetworkTracker {
    NetworkTracker(
        monitor: MockPathMonitor(),
        connectionPool: ConnectionPool { _ in service },
        failureTracker: ConnectionFailureTracker()
    )
}

/// Waits for the first state in `stream` satisfying `predicate`, or returns nil after `timeoutSeconds`.
/// Used across NetworkTracker's Swift Testing suites in place of the XCTestExpectation/
/// fulfillment(of:timeout:) pattern, which is an XCTestCase instance method and unavailable
/// from a plain Swift Testing struct.
private func firstState(
    in stream: AsyncStream<NetworkState>,
    timeoutSeconds: Double,
    where predicate: @escaping @Sendable (NetworkState) -> Bool
) async -> NetworkState? {
    await withTaskGroup(of: NetworkState?.self) { group in
        group.addTask {
            for await state in stream {
                if predicate(state) { return state }
            }
            return nil
        }
        group.addTask {
            try? await Task.sleep(for: .seconds(timeoutSeconds))
            return nil
        }
        guard let firstCompleted = await group.next() else {
            group.cancelAll()
            return nil
        }
        group.cancelAll()
        return firstCompleted
    }
}

// MARK: - Connection lifecycle (Swift Testing)

@Suite("NetworkTracker connection lifecycle")
struct NetworkTrackerConnectionLifecycleTests {
    @Test("Simulating a network-up event transitions status to .connected")
    func trackerSetsConnectedStatusOnNetworkUp() async {
        let mockService = MockOpenAPIService(returnedVersion: 8)
        let mockPool = ConnectionPool { _ in mockService }
        let mockMonitor = MockPathMonitor()

        let networkTracker = NetworkTracker(
            monitor: mockMonitor,
            connectionPool: mockPool,
            failureTracker: ConnectionFailureTracker()
        )
        let stateStream = await networkTracker.stateStream()

        let monitoringTask = Task { await mockMonitor.waitForMonitoringToStart() }
        await networkTracker.startTracking(connectionConfigurations: [defaultMockConfig])
        await monitoringTask.value
        await mockMonitor.simulateConnection(isConnected: true)

        let connected = await firstState(in: stateStream, timeoutSeconds: 2.0) { $0.status == .connected }
        #expect(connected != nil)
        await networkTracker.stopTracking()
    }

    /// The connect flow must surface the transient `.connecting` state before `.connected`.
    @Test("The connect flow surfaces the transient .connecting state before .connected")
    func trackerEmitsConnectingBeforeConnected() async {
        let tracker = makeTracker(service: MockOpenAPIService(returnedVersion: 8))
        let stateStream = await tracker.stateStream()

        await tracker.startTracking(connectionConfigurations: [defaultMockConfig])

        let connecting = await firstState(in: stateStream, timeoutSeconds: 2.0) { $0.status == .connecting }
        #expect(connecting != nil)

        // Continuing on the same stream guarantees this state was observed after .connecting.
        let connected = await firstState(in: stateStream, timeoutSeconds: 2.0) { $0.status == .connected }
        #expect(connected != nil)

        await tracker.stopTracking()
    }

    /// A failed connection must publish a `nextRetryDate` so the UI can count down to the retry.
    @Test("A failed connection publishes a nextRetryDate so the UI can count down to the retry")
    func trackerPublishesRetryDeadlineWhenConnectionFails() async {
        let tracker = makeTracker(service: MockOpenAPIService(returnedVersion: 8, shouldFail: true))
        let stateStream = await tracker.stateStream()

        await tracker.startTracking(connectionConfigurations: [defaultMockConfig])

        let retryScheduled = await firstState(in: stateStream, timeoutSeconds: 3.0) { $0.nextRetryDate != nil }
        #expect(retryScheduled != nil)

        await tracker.stopTracking()
    }

    /// `stopTracking()` must reset to `.stopped` and clear the active connection and retry deadline.
    @Test("stopTracking() resets to .stopped and clears the active connection and retry deadline")
    func stopTrackingResetsToStoppedAndClearsState() async {
        let tracker = makeTracker(service: MockOpenAPIService(returnedVersion: 8))
        let stateStream = await tracker.stateStream()

        await tracker.startTracking(connectionConfigurations: [defaultMockConfig])
        let connected = await firstState(in: stateStream, timeoutSeconds: 2.0) { $0.status == .connected }
        #expect(connected != nil)

        await tracker.stopTracking()

        let status = await tracker.status
        let activeConnection = await tracker.activeConnection
        let nextRetryDate = await tracker.nextRetryDate
        #expect(status == .stopped)
        #expect(activeConnection == nil)
        #expect(nextRetryDate == nil)
    }

    /// When a preferred connection is slow, the fallback must become active before the preferred times out.
    /// Ported from develop commit 06f0bf1c, re-expressed against stateStream() instead of statusStream().
    @Test("When the preferred connection is slow, the fallback becomes active before it times out")
    func fallbackConnectionBecomesActiveBeforePreferredConnectionTimesOut() async {
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

        let monitoringTask = Task { await mockMonitor.waitForMonitoringToStart() }
        await tracker.startTracking(connectionConfigurations: [preferredConfig, fallbackConfig])
        await monitoringTask.value
        await mockMonitor.simulateConnection(isConnected: true)

        // Fallback must win within the grace window (1s) plus some headroom — well before the 5-second preferred delay.
        let fallbackActive = await firstState(in: stateStream, timeoutSeconds: 3.0) {
            $0.activeConnection?.configuration.url == "http://fallback"
        }
        #expect(fallbackActive != nil)

        await tracker.stopTracking()
    }
}

// MARK: - Client-error retry (Swift Testing)

@Suite("NetworkTracker client-error retry")
struct NetworkTrackerClientErrorRetryTests {
    /// A transient ClientError must trigger revalidateConnection() and one retry; the overall call succeeds.
    /// Covers the withClientErrorRetry/revalidateConnection resilience ported in develop commit 9de4e7f0.
    @Test("A transient ClientError triggers revalidateConnection() and one retry; the overall call succeeds")
    func clientErrorTriggersRevalidateAndRetry() async throws {
        let service = MockOpenAPIService(returnedVersion: 8, clientErrorsBeforeSuccess: 1)
        let tracker = NetworkTracker(
            monitor: MockPathMonitor(),
            connectionPool: ConnectionPool { _ in service },
            failureTracker: ConnectionFailureTracker()
        )

        await tracker.startTracking(connectionConfigurations: [defaultMockConfig])
        let activeConnection = await tracker.waitForActiveConnection()
        #expect(activeConnection != nil)

        // First sendItemCommand throws ClientError → revalidateConnection() → retry succeeds.
        try await tracker.send(to: "TestItem", command: "ON", deviceId: nil)

        let callCount = await service.sendCommandCallCount
        #expect(callCount == 2, "Expected 1 failed attempt + 1 successful retry")
        await tracker.stopTracking()
    }
}

// MARK: - Network-loss handling (Swift Testing)

@Suite("NetworkTracker network-loss handling")
struct NetworkTrackerNetworkLossTests {
    /// A network-down event must mark the network unavailable and abandon the pending retry.
    @Test("Network loss marks isNetworkAvailable false and abandons the pending retry")
    func networkLossMarksUnavailableAndAbandonsRetry() async {
        let mockMonitor = MockPathMonitor()
        let tracker = NetworkTracker(
            monitor: mockMonitor,
            connectionPool: ConnectionPool { _ in MockOpenAPIService(returnedVersion: 8, shouldFail: true) },
            failureTracker: ConnectionFailureTracker()
        )
        let stateStream = await tracker.stateStream()

        await tracker.startTracking(connectionConfigurations: [defaultMockConfig])
        // The failing connection schedules a retry (sets nextRetryDate).
        let retryScheduled = await firstState(in: stateStream, timeoutSeconds: 3.0) { $0.nextRetryDate != nil }
        #expect(retryScheduled != nil)

        // Once the path monitor is active, a network-down event must abandon that retry.
        await mockMonitor.waitForMonitoringToStart()
        await mockMonitor.simulateConnection(isConnected: false)

        let networkUnavailable = await firstState(in: stateStream, timeoutSeconds: 3.0) {
            !$0.isNetworkAvailable && $0.nextRetryDate == nil
        }
        #expect(networkUnavailable != nil)

        await tracker.stopTracking()
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
