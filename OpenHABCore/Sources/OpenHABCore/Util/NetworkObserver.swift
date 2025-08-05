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

import Foundation
import Kingfisher
import os.log

public actor NetworkObserver {
    public static let shared = NetworkObserver()

    private var viewModel: NetworkTrackerViewModel?

    private var pathMonitor: any NWPathMonitoring = RealPathMonitor()
    private var connectionPool = ConnectionPool()
    private var failureTracker = ConnectionFailureTracker()
    private var connectionConfigurations: [ConnectionConfiguration] = []
    private var retryTask: Task<Void, Never>?

    private let logger = Logger(subsystem: "org.openhab.core", category: "NetworkObserver")

    private let allowUIEffects: Bool

    init(allowUIEffects: Bool = true) {
        self.allowUIEffects = allowUIEffects
    }

    private static func makeNetworkHandler(for observer: NetworkObserver?) -> @Sendable (Bool) -> Void {
        { isConnected in
            Task.detached(priority: .utility) {
                guard let observer else { return }
                await observer.handleNetworkChange(isConnected: isConnected)
            }
        }
    }

    public func bind(to viewModel: NetworkTrackerViewModel) {
        self.viewModel = viewModel
    }

    public func startTracking(connectionConfigurations: [ConnectionConfiguration]) {
        self.connectionConfigurations = connectionConfigurations

        Task { [weak self] in
            guard let self else { return }
            let handler = Self.makeNetworkHandler(for: self)
            await pathMonitor.startMonitoring(handler: handler)
        }

        Task {
            await self.attemptConnection()
        }
    }

    private func attemptConnection() async {
        guard !connectionConfigurations.isEmpty else {
            await updateUI(status: .notConnected, connection: nil)
            return
        }

        logger.debug("Checking available connections...")

        let sortedConfigs = connectionConfigurations.sorted { $0.priority < $1.priority }
        var bestConnection: ConnectionInfo?
        var connectedCount = 0

        await withTaskGroup(of: ConnectionInfo?.self) { group in
            for config in sortedConfigs {
                group.addTask {
                    await self.testConnection(configuration: config)
                }
            }

            for await connectionInfo in group {
                guard let connectionInfo else { continue }
                connectedCount += 1

                if connectionInfo.configuration.priority == 0 {
                    bestConnection = connectionInfo
                    group.cancelAll()
                    break
                }

                if bestConnection == nil || connectionInfo.configuration.priority < bestConnection!.configuration.priority {
                    bestConnection = connectionInfo
                }
            }
        }

        let newStatus: NetworkStatus = switch connectedCount {
        case 0: .notConnected
        case 1: .someConnected
        default: .allConnected
        }

        await updateUI(status: newStatus, connection: bestConnection)

        if allowUIEffects, let best = bestConnection {
            KingfisherManager.shared.defaultOptions = [
                .requestModifier(OpenHABAccessTokenAdapter(connectionConfiguration: best.configuration))
            ]
        } else {
            await startRetryTask()
        }
    }

    private func updateUI(status: NetworkStatus, connection: ConnectionInfo?) async {
        let viewModel = viewModel
        await MainActor.run {
            viewModel?.updateStatus(status, connection: connection)
        }
    }

    private func startRetryTask() async {
        retryTask?.cancel()

        let backoffMultiplier = await failureTracker.maxFailureCount()
        let safeBackoff = min(backoffMultiplier, 10)
        let delay: UInt64 = min(30 * (1 << safeBackoff), 300)

        retryTask = Task.detached {
            self.logger.info("Retrying in \(delay) seconds")
            try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
            if !Task.isCancelled {
                await self.attemptConnection()
            }
        }
    }

    private func handleNetworkChange(isConnected: Bool) async {
        if isConnected {
            await attemptConnection()
        } else {
            await updateUI(status: .notConnected, connection: nil)
            await startRetryTask()
        }
    }

    private func testConnection(configuration: ConnectionConfiguration) async -> ConnectionInfo? {
        guard await failureTracker.shouldAttempt(configuration) else {
            logger.info("Skipping \(configuration.url) due to failures")
            return nil
        }

        do {
            logger.info("Testing connection for \(configuration.url)")
            let service = try await connectionPool.getOrCreateService(for: configuration)
            let version = try await service.getRootVersion()
            let info = ConnectionInfo(configuration: configuration, version: version)

            await failureTracker.reset(configuration)
            return info
        } catch {
            await failureTracker.recordFailure(configuration)
            logger.info("Connection failed: \(configuration.url): \(error.localizedDescription)")
            return nil
        }
    }

    public func resetFailures() {
        Task { await failureTracker.resetAll() }
    }

    public func send(to item: String, command: String) async throws {
        guard let connection = await viewModel?.activeConnection else { return }
        let service = try await connectionPool.getOrCreateService(for: connection.configuration)
        try await service.sendItemCommand(itemname: item, command: command)
    }

    public func updateState(for item: String, state: String) async throws {
        guard let connection = await viewModel?.activeConnection else { return }
        let service = try await connectionPool.getOrCreateService(for: connection.configuration)
        try await service.updateItemState(itemname: item, with: state)
    }

    public func getItems() async throws -> [OpenHABItem] {
        guard let connection = await viewModel?.activeConnection else { return [] }
        let service = try await connectionPool.getOrCreateService(for: connection.configuration)
        return try await service.getItems()
    }

    public func getItemByName(id: String) async throws -> OpenHABItem? {
        guard let connection = await viewModel?.activeConnection else { return nil }
        let service = try await connectionPool.getOrCreateService(for: connection.configuration)
        return try await service.getItemByName(id: id)
    }

    public func pollDataForPage(sitemapname: String, pageId: String = "", longPolling: Bool = false) async throws -> OpenHABPage? {
        guard let connection = await viewModel?.activeConnection else { return nil }
        let service = try await connectionPool.getOrCreateService(for: connection.configuration)
        return try await service.pollDataForPage(sitemapname: sitemapname, pageId: pageId, longPolling: longPolling)
    }

    public func runNow(ruleUID: String, payload: [String: String]) async throws {
        guard let connection = await viewModel?.activeConnection else { throw NetworkTrackerError.noActiveConnection }
        let service = try await connectionPool.getOrCreateService(for: connection.configuration)
        try await service.runNow(ruleUID: ruleUID, payload: payload)
    }
}
