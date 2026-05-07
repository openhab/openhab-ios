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
import OpenAPIRuntime
import OpenAPIURLSession
import OSLog

/*
 Example usage:

 ```
 ItemEventStream.startMonitoringNetwork()
 Task {
     await ItemEventStream.trackItems(["PanelDansOffice", "F1_Kitchen"])
 }
 print("Starting SSE")
 streamTask = Task { [weak self] in
     guard let self else { return }
     for await msg in await ItemEventStream.stream() {
         await MainActor.run { self.handle(msg) }
     }
 }
 ```
 */

public enum StreamOutput<Event: Sendable>: Sendable {
    case connected
    case disconnected((any Error)?) // `nil` when closed intentionally
    case event(Event)
}

public enum StateStreamMessage: Sendable, Equatable {
    case ready(uuid: String, lastEventID: String?)
    case state(item: String, state: String)
    case alive(interval: Int)
    case unknown(raw: String)
}

public actor EventStream<Event: Sendable> {
    /// Alive and Item State Chnage message structures
    private struct Alive: Decodable { let type: String; let interval: Int }
    /// Multiple items can come in a single message which makes this a little more complicated
    private struct ItemStateChanges: Decodable {
        struct Value: Decodable { let state: String }

        let wrapped: [String: Value]
        var first: (String, Value)? {
            wrapped.first
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            wrapped = try container.decode([String: Value].self)
        }
    }

    private var trackedItemsByNamespace: [String: Set<String>] = [:]
    private var trackedItems: Set<String> {
        trackedItemsByNamespace.values.reduce(into: Set()) { $0.formUnion($1) }
    }

    private var continuations = [UUID: AsyncStream<StreamOutput<Event>>.Continuation]()
    private var listenTask: Task<Void, Never>?
    private var networkMonitoringTask: Task<Void, Never>?
    private var currentConfig: ConnectionConfiguration?
    private var sessionUUID: String?
    private var service: OpenAPIService?
    private var lastEventTime = Date.now
    private let jsonDecoder = JSONDecoder()

    public func stream() -> AsyncStream<StreamOutput<Event>> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { [id] in
                    await self.cleanupContinuation(id)
                }
            }
        }
    }

    public func setItems(_ items: [String], for namespace: String) async {
        trackedItemsByNamespace[namespace] = Set(items)
        await sendTrackedItemsIfPossible()
    }

    /// Sets items for the ``"default"`` namespace. Use ``setItems(_:for:)`` when multiple
    /// callers need to track independent sets simultaneously.
    public func trackItems(_ items: [String]) async {
        await setItems(items, for: "default")
    }

    public func startMonitoringNetworkIfNeeded(initialConnection: ConnectionInfo?) {
        updateConnection(initialConnection)

        // Keep network monitoring alive for the actor lifetime. Stop/restart
        // behaviour is handled by updateConnection cancelling listenTask.
        guard networkMonitoringTask == nil else { return }

        networkMonitoringTask = Task { [weak self] in
            guard let self else { return }
            for await conn in await NetworkTracker.shared.activeConnectionStream() {
                await updateConnection(conn)
            }
        }
    }

    private func cleanupContinuation(_ id: UUID) {
        continuations[id]?.finish()
        continuations.removeValue(forKey: id)
    }

    /// NetworkManager callback
    private func updateConnection(_ info: ConnectionInfo?) {
        let newConfig = info?.configuration

        guard currentConfig != newConfig else { return }

        currentConfig = info?.configuration

        Logger.restAPI.info("Network changed – restarting SSE connection")

        listenTask?.cancel()
        listenTask = nil

        guard let cfg = currentConfig else {
            broadcast(.disconnected(nil))
            return
        }
        listenTask = Task { await listen(using: cfg) }
    }

    /// Try and send the item right away, if the connection is not up, they will be sent when its ready
    private func sendTrackedItemsIfPossible() async {
        guard
            !trackedItems.isEmpty,
            let uuid = sessionUUID,
            let service
        else { return }
        do {
            try await service.updateItemListForStateUpdates(
                connectionId: uuid,
                items: Array(trackedItems)
            )
        } catch {
            Logger.restAPI.error("Failed to update item list: \(error.localizedDescription)")
        }
    }

    private func listen(using config: ConnectionConfiguration) async {
        var backoff: TimeInterval = 1
        let maxBackoff: TimeInterval = 30

        while !Task.isCancelled {
            do {
                let service = try OpenAPIService(connectionConfiguration: config)
                let response = try await service.initNewStateTacker()
                let eventStream = try response.ok.body.text_event_hyphen_stream.asDecodedServerSentEvents()
                self.service = service
                broadcast(.connected)
                lastEventTime = .now

                let watchdog = Task { [weak self] in
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(10))
                        guard !Task.isCancelled else { return }
                        guard let self else { return }
                        await checkAliveWatchdog()
                    }
                }
                defer { watchdog.cancel() }

                for try await sse in eventStream {
                    lastEventTime = .now
                    for rawMessage in parse(sse) {
                        if let message = rawMessage as? Event {
                            broadcast(.event(message))
                        }
                    }
                }
                // if we get here we have lost the connection
                throw CancellationError()
            } catch is CancellationError {
                // normal cleanup, just return
                return
            } catch {
                broadcast(.disconnected(error))
                // give a little time before we try connecting again
                Logger.restAPI.error("SSE error: \(error.localizedDescription, privacy: .public) – retrying in \(backoff, privacy: .public)s")
                try? await Task.sleep(for: .seconds(backoff))
                backoff = min(backoff * 2, maxBackoff)
            }
        }
    }

    /// Reconnects if no SSE events have been received for 30 seconds.
    /// The server sends ALIVE heartbeats every ~10 s, so 30 s of silence
    /// indicates a silently dead connection (e.g. after a server restart).
    private func checkAliveWatchdog() {
        guard Date.now.timeIntervalSince(lastEventTime) > 30 else { return }
        Logger.restAPI.warning("Item SSE watchdog: no events for 30 s, reconnecting")
        restartListening()
    }

    private func restartListening() {
        guard let cfg = currentConfig else {
            broadcast(.disconnected(nil))
            return
        }
        listenTask?.cancel()
        listenTask = Task { await listen(using: cfg) }
    }

    private func broadcast(_ msg: StreamOutput<Event>) {
        // the "ready" message carries the UUID string we need to store
        if case let .event(raw as StateStreamMessage) = msg,
           case let .ready(uuid, _) = raw {
            sessionUUID = uuid
            // Re‑send the item subscription when we have a fresh UUID.
            Task { await self.sendTrackedItemsIfPossible() }
        }
        continuations.values.forEach { $0.yield(msg) }
    }

    private func parse(_ sse: ServerSentEvent) -> [StateStreamMessage] {
        switch sse.event ?? "" {
        case "ready":
            if let uuid = sse.data {
                return [.ready(uuid: uuid, lastEventID: sse.id)]
            }
        case "alive":
            if let data = sse.data!.data(using: String.Encoding.utf8),
               let obj = try? jsonDecoder.decode(
                   Alive.self, from: data
               ) {
                return [.alive(interval: obj.interval)]
            }
        default:
            // sometime message omit the `event:` field and send only `data:` with the JSON.
            if let data = sse.data?.data(using: String.Encoding.utf8),
               let changes = try? jsonDecoder.decode(ItemStateChanges.self, from: data) {
                return changes.wrapped.map { key, value in
                    .state(item: key, state: value.state)
                }
            }
        }
        return [.unknown(raw: sse.data ?? "nil")]
    }
}

/// Helper so callers can just use `ItemEventStream` and not  EventStream<StateStreamMessage>
public typealias ItemEventStream = EventStream<StateStreamMessage>

public extension ItemEventStream {
    static let shared = ItemEventStream()
    /// helper function so callers can write something like:
    /// `await ItemEventStream.trackItems(["KitchenLight"])`.
    nonisolated static func trackItems(_ items: [String]) async {
        await shared.trackItems(items)
    }

<<<<<<< HEAD
    nonisolated static func setItems(_ items: [String], for namespace: String) async {
        await shared.setItems(items, for: namespace)
    }

=======
>>>>>>> c1160165 (Fix SSE startup race and eliminate MainActor dispatch overhead)
    static func startMonitoringNetwork(initialConnection: ConnectionInfo? = nil) async {
        await shared.startMonitoringNetworkIfNeeded(initialConnection: initialConnection)
    }
}
