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
@testable import openHAB
import OpenHABCore
import Testing

// MARK: - Mock Bonjour Service

final class MockBonjourService: BonjourServiceProtocol, @unchecked Sendable {
    var startCalled = false
    var stopCalled = false
    var startCycles: Int?
    var startCycleDuration: TimeInterval?

    private var onUpdateCallback: (@Sendable ([DiscoveredServer]) -> Void)?
    private var onCompleteCallback: (@Sendable () -> Void)?

    private var injectedServers: [DiscoveredServer] = []

    func start(cycles: Int,
               cycleDuration: TimeInterval,
               onUpdate: @escaping @Sendable ([DiscoveredServer]) -> Void,
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

@Suite("BonjourDiscoveryViewModel")
@MainActor
struct BonjourDiscoveryViewModelTests {
    // MARK: - Initial State Tests

    @Test
    func initialState() {
        let viewModel = BonjourDiscoveryViewModel { MockBonjourService() }

        #expect(viewModel.discoveredURLs == [])
        #expect(viewModel.isDiscovering == false)
        #expect(viewModel.discoveryCycles == 2)
        #expect(viewModel.cycleDuration == 5)
    }

    // MARK: - Discovery Lifecycle Tests

    @Test
    func discoverAllSetsIsDiscoveringToTrue() {
        let mockService = MockBonjourService()
        let viewModel = BonjourDiscoveryViewModel { mockService }

        viewModel.discoverAll()

        #expect(viewModel.isDiscovering == true)
    }

    @Test
    func discoverAllClearsExistingURLs() {
        let mockService = MockBonjourService()
        let viewModel = BonjourDiscoveryViewModel { mockService }
        viewModel.discoveredURLs = ["http://old.server:8080"]

        viewModel.discoverAll()

        #expect(viewModel.discoveredURLs == [])
    }

    @Test
    func discoverAllStartsService() {
        let mockService = MockBonjourService()
        let viewModel = BonjourDiscoveryViewModel { mockService }

        viewModel.discoverAll()

        #expect(mockService.startCalled == true)
    }

    @Test
    func discoverAllPassesConfigurationToService() {
        let mockService = MockBonjourService()
        let viewModel = BonjourDiscoveryViewModel { mockService }
        viewModel.discoveryCycles = 3
        viewModel.cycleDuration = 10

        viewModel.discoverAll()

        #expect(mockService.startCycles == 3)
        #expect(mockService.startCycleDuration == 10)
    }

    @Test
    func completionSetsIsDiscoveringToFalse() async throws {
        let mockService = MockBonjourService()
        let viewModel = BonjourDiscoveryViewModel { mockService }

        viewModel.discoverAll()
        #expect(viewModel.isDiscovering == true)

        mockService.simulateCompletion()

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(viewModel.isDiscovering == false)
    }

    @Test
    func completionStopsService() async throws {
        let mockService = MockBonjourService()
        let viewModel = BonjourDiscoveryViewModel { mockService }

        viewModel.discoverAll()
        mockService.simulateCompletion()

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(mockService.stopCalled == true)
    }

    // MARK: - Server Discovery Tests

    @Test
    func discoveredServersAreAddedToURLs() async throws {
        let mockService = MockBonjourService()
        let viewModel = BonjourDiscoveryViewModel { mockService }

        viewModel.discoverAll()

        let servers = [
            DiscoveredServer(scheme: "http", address: "192.168.1.1", port: 8080),
            DiscoveredServer(scheme: "https", address: "192.168.1.1", port: 8443)
        ]
        mockService.simulateDiscovery(servers: servers)

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(viewModel.discoveredURLs.count == 2)
        #expect(viewModel.discoveredURLs.contains("http://192.168.1.1:8080"))
        #expect(viewModel.discoveredURLs.contains("https://192.168.1.1:8443"))
    }

    // MARK: - URL Deduplication Tests

    @Test
    func duplicateURLsAreNotAdded() async throws {
        let mockService = MockBonjourService()
        let viewModel = BonjourDiscoveryViewModel { mockService }

        viewModel.discoverAll()

        let servers = [
            DiscoveredServer(scheme: "http", address: "192.168.1.1", port: 8080)
        ]

        mockService.simulateDiscovery(servers: servers)
        try await Task.sleep(nanoseconds: 50_000_000)

        mockService.simulateDiscovery(servers: servers)
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(viewModel.discoveredURLs.count == 1)
    }

    @Test
    func multipleUpdatesAccumulateUniqueURLs() async throws {
        let mockService = MockBonjourService()
        let viewModel = BonjourDiscoveryViewModel { mockService }

        viewModel.discoverAll()

        mockService.simulateDiscovery(servers: [
            DiscoveredServer(scheme: "http", address: "192.168.1.1", port: 8080)
        ])
        try await Task.sleep(nanoseconds: 50_000_000)

        mockService.simulateDiscovery(servers: [
            DiscoveredServer(scheme: "http", address: "192.168.1.1", port: 8080),
            DiscoveredServer(scheme: "http", address: "192.168.1.2", port: 8080)
        ])
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(viewModel.discoveredURLs.count == 2)
        #expect(viewModel.discoveredURLs.contains("http://192.168.1.1:8080"))
        #expect(viewModel.discoveredURLs.contains("http://192.168.1.2:8080"))
    }

    // MARK: - Reset Tests

    @Test
    func resetDiscoveredUrlsClearsURLs() {
        let mockService = MockBonjourService()
        let viewModel = BonjourDiscoveryViewModel { mockService }
        viewModel.discoveredURLs = ["http://test:8080"]

        viewModel.resetDiscoveredUrls()

        #expect(viewModel.discoveredURLs == [])
    }

    @Test
    func resetDiscoveredUrlsSetsIsDiscoveringToFalse() {
        let mockService = MockBonjourService()
        let viewModel = BonjourDiscoveryViewModel { mockService }

        viewModel.discoverAll()
        #expect(viewModel.isDiscovering == true)

        viewModel.resetDiscoveredUrls()

        #expect(viewModel.isDiscovering == false)
    }

    @Test
    func resetDiscoveredUrlsStopsService() {
        let mockService = MockBonjourService()
        let viewModel = BonjourDiscoveryViewModel { mockService }

        viewModel.discoverAll()
        viewModel.resetDiscoveredUrls()

        #expect(mockService.stopCalled == true)
    }

    // MARK: - State Management Tests

    @Test
    func startingNewDiscoveryWhileDiscoveringResetsState() async throws {
        let mockService = MockBonjourService()
        let viewModel = BonjourDiscoveryViewModel { mockService }

        viewModel.discoverAll()

        mockService.simulateDiscovery(servers: [
            DiscoveredServer(scheme: "http", address: "192.168.1.1", port: 8080)
        ])
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(viewModel.discoveredURLs.count == 1)

        viewModel.discoverAll()

        #expect(viewModel.discoveredURLs == [])
        #expect(viewModel.isDiscovering == true)
    }

    // MARK: - URL Ordering Tests

    @Test
    func urlsAreAddedInDiscoveryOrder() async throws {
        let mockService = MockBonjourService()
        let viewModel = BonjourDiscoveryViewModel { mockService }

        viewModel.discoverAll()

        mockService.simulateDiscovery(servers: [
            DiscoveredServer(scheme: "http", address: "192.168.1.3", port: 8080),
            DiscoveredServer(scheme: "http", address: "192.168.1.1", port: 8080),
            DiscoveredServer(scheme: "http", address: "192.168.1.2", port: 8080)
        ])
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(viewModel.discoveredURLs[0] == "http://192.168.1.3:8080")
        #expect(viewModel.discoveredURLs[1] == "http://192.168.1.1:8080")
        #expect(viewModel.discoveredURLs[2] == "http://192.168.1.2:8080")
    }

    // MARK: - IPv6 Tests

    @Test
    func ipv6AddressesAreHandledCorrectly() async throws {
        let mockService = MockBonjourService()
        let viewModel = BonjourDiscoveryViewModel { mockService }

        viewModel.discoverAll()

        mockService.simulateDiscovery(servers: [
            DiscoveredServer(scheme: "http", address: "[2001:db8::1]", port: 8080)
        ])
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(viewModel.discoveredURLs.contains("http://[2001:db8::1]:8080"))
    }
}
