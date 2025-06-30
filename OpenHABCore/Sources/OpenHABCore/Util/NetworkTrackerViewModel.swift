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

@preconcurrency import Combine

@MainActor
public final class NetworkTrackerViewModel: ObservableObject {
    @Published public private(set) var activeConnection: ConnectionInfo?
    @Published public private(set) var status: NetworkStatus = .connecting

    private let observer: NetworkObserver

    public init(observer: NetworkObserver = .shared) async {
        self.observer = observer
        await observer.bind(to: self) // ✅ Now allowed
    }

    public func startTracking(with configurations: [ConnectionConfiguration]) async {
        await observer.startTracking(connectionConfigurations: configurations)
    }

    public func send(to item: OpenHABItem, command: String) async throws {
        try await observer.send(to: item.name, command: command)
    }

    public func updateState(for item: OpenHABItem, state: String) async throws {
        try await observer.updateState(for: item.name, state: state)
    }

    public func getItems() async throws -> [OpenHABItem] {
        try await observer.getItems()
    }

    public func getItemByName(id: String) async throws -> OpenHABItem? {
        try await observer.getItemByName(id: id)
    }

    public func pollDataForPage(sitemapname: String, pageId: String = "", longPolling: Bool = false) async throws -> OpenHABPage? {
        try await observer.pollDataForPage(sitemapname: sitemapname, pageId: pageId, longPolling: longPolling)
    }

    public func runNow(ruleUID: String, payload: [String: String]) async throws {
        try await observer.runNow(ruleUID: ruleUID, payload: payload)
    }

    public func resetFailures() async {
        await observer.resetFailures()
    }

    // Internal API for observer updates
    func updateStatus(_ status: NetworkStatus, connection: ConnectionInfo?) {
        Task { @MainActor in
            self.status = status
            self.activeConnection = connection
        }
    }

    func activeConnectionStream() -> AsyncStream<ConnectionInfo?> {
        AsyncStream { continuation in
            let cancellable = self.$activeConnection
                .sink { continuation.yield($0) }

            continuation.onTermination = { [cancellable] _ in cancellable.cancel() }
        }
    }
}
