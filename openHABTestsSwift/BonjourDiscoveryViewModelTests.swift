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

@testable import openHAB
import OpenHABCore
import XCTest

// MARK: - Mock Bonjour Service

final class MockBonjourService: BonjourServiceProtocol, @unchecked Sendable {
    var startCalled = false
    var stopCalled = false
    var startCycles: Int?
    var startCycleDuration: TimeInterval?

    private var onUpdateCallback: (([DiscoveredServer]) -> Void)?
    private var onCompleteCallback: (() -> Void)?

    private var injectedServers: [DiscoveredServer] = []

    func start(cycles: Int,
               cycleDuration: TimeInterval,
               onUpdate: @escaping ([DiscoveredServer]) -> Void,
               onComplete: (@Sendable () -> Void)?) {
        startCalled = true
        startCycles = cycles
        startCycleDuration = cycleDuration
        onUpdateCallback = onUpdate
        onCompleteCallback = onComplete
    }

    func stop() {
        stopCalled = true
    }

    func getDiscoveredServers() -> [DiscoveredServer] {
        injectedServers
    }

    // Test helpers

    func simulateDiscovery(servers: [DiscoveredServer]) {
        injectedServers = servers
        onUpdateCallback?(servers)
    }

    func simulateCompletion() {
        onCompleteCallback?()
    }
}

// MARK: - BonjourDiscoveryViewModel Tests

@MainActor
final class BonjourDiscoveryViewModelTests: XCTestCase {
    var mockService: MockBonjourService!
    var viewModel: BonjourDiscoveryViewModel!

    override func setUp() async throws {
        try await super.setUp()
        mockService = MockBonjourService()
        let service = mockService!
        viewModel = BonjourDiscoveryViewModel { service }
    }

    override func tearDown() async throws {
        viewModel = nil
        mockService = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertEqual(viewModel.discoveredURLs, [])
        XCTAssertFalse(viewModel.isDiscovering)
        XCTAssertEqual(viewModel.discoveryCycles, 2)
        XCTAssertEqual(viewModel.cycleDuration, 5)
    }

    // MARK: - Discovery Lifecycle Tests

    func testDiscoverAllSetsIsDiscoveringToTrue() {
        viewModel.discoverAll()

        XCTAssertTrue(viewModel.isDiscovering)
    }

    func testDiscoverAllClearsExistingURLs() {
        // Pre-populate with URLs
        viewModel.discoveredURLs = ["http://old.server:8080"]

        viewModel.discoverAll()

        XCTAssertEqual(viewModel.discoveredURLs, [])
    }

    func testDiscoverAllStartsService() {
        viewModel.discoverAll()

        XCTAssertTrue(mockService.startCalled)
    }

    func testDiscoverAllPassesConfigurationToService() {
        viewModel.discoveryCycles = 3
        viewModel.cycleDuration = 10

        viewModel.discoverAll()

        XCTAssertEqual(mockService.startCycles, 3)
        XCTAssertEqual(mockService.startCycleDuration, 10)
    }

    func testCompletionSetsIsDiscoveringToFalse() async throws {
        viewModel.discoverAll()
        XCTAssertTrue(viewModel.isDiscovering)

        mockService.simulateCompletion()

        // Wait for async Task to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        XCTAssertFalse(viewModel.isDiscovering)
    }

    func testCompletionStopsService() async throws {
        viewModel.discoverAll()

        mockService.simulateCompletion()

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(mockService.stopCalled)
    }

    // MARK: - Server Discovery Tests

    func testDiscoveredServersAreAddedToURLs() async throws {
        viewModel.discoverAll()

        let servers = [
            DiscoveredServer(scheme: "http", address: "192.168.1.1", port: 8080),
            DiscoveredServer(scheme: "https", address: "192.168.1.1", port: 8443)
        ]
        mockService.simulateDiscovery(servers: servers)

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.discoveredURLs.count, 2)
        XCTAssertTrue(viewModel.discoveredURLs.contains("http://192.168.1.1:8080"))
        XCTAssertTrue(viewModel.discoveredURLs.contains("https://192.168.1.1:8443"))
    }

    // MARK: - URL Deduplication Tests

    func testDuplicateURLsAreNotAdded() async throws {
        viewModel.discoverAll()

        let servers = [
            DiscoveredServer(scheme: "http", address: "192.168.1.1", port: 8080)
        ]

        // Simulate discovery twice with the same server
        mockService.simulateDiscovery(servers: servers)
        try await Task.sleep(nanoseconds: 50_000_000)

        mockService.simulateDiscovery(servers: servers)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.discoveredURLs.count, 1)
    }

    func testMultipleUpdatesAccumulateUniqueURLs() async throws {
        viewModel.discoverAll()

        // First update
        mockService.simulateDiscovery(servers: [
            DiscoveredServer(scheme: "http", address: "192.168.1.1", port: 8080)
        ])
        try await Task.sleep(nanoseconds: 50_000_000)

        // Second update with new server
        mockService.simulateDiscovery(servers: [
            DiscoveredServer(scheme: "http", address: "192.168.1.1", port: 8080),
            DiscoveredServer(scheme: "http", address: "192.168.1.2", port: 8080)
        ])
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.discoveredURLs.count, 2)
        XCTAssertTrue(viewModel.discoveredURLs.contains("http://192.168.1.1:8080"))
        XCTAssertTrue(viewModel.discoveredURLs.contains("http://192.168.1.2:8080"))
    }

    // MARK: - Reset Tests

    func testResetDiscoveredUrlsClearsURLs() {
        viewModel.discoveredURLs = ["http://test:8080"]

        viewModel.resetDiscoveredUrls()

        XCTAssertEqual(viewModel.discoveredURLs, [])
    }

    func testResetDiscoveredUrlsSetsIsDiscoveringToFalse() {
        viewModel.discoverAll()
        XCTAssertTrue(viewModel.isDiscovering)

        viewModel.resetDiscoveredUrls()

        XCTAssertFalse(viewModel.isDiscovering)
    }

    func testResetDiscoveredUrlsStopsService() {
        viewModel.discoverAll()

        viewModel.resetDiscoveredUrls()

        XCTAssertTrue(mockService.stopCalled)
    }

    // MARK: - State Management Tests

    func testStartingNewDiscoveryWhileDiscoveringResetsState() async throws {
        viewModel.discoverAll()

        mockService.simulateDiscovery(servers: [
            DiscoveredServer(scheme: "http", address: "192.168.1.1", port: 8080)
        ])
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.discoveredURLs.count, 1)

        // Start new discovery
        viewModel.discoverAll()

        XCTAssertEqual(viewModel.discoveredURLs, [])
        XCTAssertTrue(viewModel.isDiscovering)
    }

    // MARK: - URL Ordering Tests

    func testURLsAreAddedInDiscoveryOrder() async throws {
        viewModel.discoverAll()

        mockService.simulateDiscovery(servers: [
            DiscoveredServer(scheme: "http", address: "192.168.1.3", port: 8080),
            DiscoveredServer(scheme: "http", address: "192.168.1.1", port: 8080),
            DiscoveredServer(scheme: "http", address: "192.168.1.2", port: 8080)
        ])
        try await Task.sleep(nanoseconds: 50_000_000)

        // URLs should be in the order they were discovered
        XCTAssertEqual(viewModel.discoveredURLs[0], "http://192.168.1.3:8080")
        XCTAssertEqual(viewModel.discoveredURLs[1], "http://192.168.1.1:8080")
        XCTAssertEqual(viewModel.discoveredURLs[2], "http://192.168.1.2:8080")
    }

    // MARK: - IPv6 Tests

    func testIPv6AddressesAreHandledCorrectly() async throws {
        viewModel.discoverAll()

        mockService.simulateDiscovery(servers: [
            DiscoveredServer(scheme: "http", address: "[2001:db8::1]", port: 8080)
        ])
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(viewModel.discoveredURLs.contains("http://[2001:db8::1]:8080"))
    }
}
