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
import HTTPTypes
import OpenAPIRuntime
import OSLog

public enum SitemapSseError: Error, Equatable {
    case unsupported
}

public enum SitemapEventMessage: Sendable {
    case alive
    case sitemapChanged(sitemap: String?, pageId: String?)
    case widget(OpenHABSitemapWidgetEvent)
    case unknown(raw: String)
}

public actor SitemapEventStream {
    public init() {}

    private struct Target: Equatable {
        let sitemap: String
        let pageId: String
    }

    private var continuations = [UUID: AsyncStream<StreamOutput<SitemapEventMessage>>.Continuation]()
    private var listenTask: Task<Void, Never>?
    private var networkMonitoringTask: Task<Void, Never>?
    private var currentConfig: ConnectionConfiguration?
    private var currentTarget: Target?
    private var isStopped = false
    private var lastEventTime = Date.now
    private let jsonDecoder = JSONDecoder()

    public func stream(sitemap: String, pageId: String) -> AsyncStream<StreamOutput<SitemapEventMessage>> {
        isStopped = false
        let target = Target(sitemap: sitemap, pageId: pageId)
        if currentTarget != target {
            Logger.restAPI.info("Sitemap SSE target set to \(sitemap)/\(pageId)")
            currentTarget = target
            listenTask?.cancel()
            listenTask = nil
        }

        // Flush stale continuations synchronously before registering a new one.
        // Because stream(sitemap:pageId:) is actor-isolated this is atomic — no race with broadcast().
        continuations.values.forEach { $0.finish() }
        continuations.removeAll()

        let stream = AsyncStream<StreamOutput<SitemapEventMessage>> { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { [id] in
                    await self.cleanupContinuation(id)
                }
            }
        }

        // Always ensure the listen task is running, even when the target didn't change.
        // cleanupContinuation may have cancelled it when the last consumer left.
        restartListeningIfNeeded()
        return stream
    }

    public func stop() async {
        isStopped = true
        currentTarget = nil
        listenTask?.cancel()
        listenTask = nil
    }

    public func startMonitoringNetworkIfNeeded(initialConnection: ConnectionInfo?) {
        updateConnection(initialConnection)

        // Keep network monitoring alive for the actor lifetime. Stop/restart
        // behavior is handled by updateConnection cancelling listenTask.
        guard networkMonitoringTask == nil else { return }

        networkMonitoringTask = Task { [weak self] in
            for await conn in await NetworkTracker.shared.activeConnectionStream() {
                guard let self else { return }
                await updateConnection(conn)
            }
        }
    }

    private func cleanupContinuation(_ id: UUID) {
        continuations[id]?.finish()
        continuations.removeValue(forKey: id)
        if continuations.isEmpty {
            listenTask?.cancel()
            listenTask = nil
        }
    }

    private func updateConnection(_ info: ConnectionInfo?) {
        let newConfig = info?.configuration

        guard currentConfig != newConfig else { return }

        currentConfig = info?.configuration

        Logger.restAPI.info("Network changed – restarting sitemap SSE connection")

        listenTask?.cancel()
        listenTask = nil

        restartListeningIfPossible()
    }

    private func restartListeningIfNeeded() {
        guard !isStopped, listenTask == nil else { return }
        guard let cfg = currentConfig, let target = currentTarget else { return }
        Logger.restAPI.info("Starting sitemap SSE listener for \(target.sitemap)/\(target.pageId)")
        listenTask = Task { await listen(using: cfg, target: target) }
    }

    private func restartListeningIfPossible() {
        guard !isStopped else { return }
        guard let cfg = currentConfig, let target = currentTarget else {
            broadcast(.disconnected(nil))
            return
        }
        Logger.restAPI.info("Starting sitemap SSE listener for \(target.sitemap)/\(target.pageId)")
        listenTask?.cancel()
        listenTask = Task { await listen(using: cfg, target: target) }
    }

    private func listen(using config: ConnectionConfiguration, target: Target) async {
        var backoff: TimeInterval = 1
        let maxBackoff: TimeInterval = 30

        while !Task.isCancelled {
            do {
                let service = try OpenAPIService(connectionConfiguration: config)
                guard let subscriptionId = try await service.openHABcreateSubscription() else {
                    throw SitemapSseError.unsupported
                }
                Logger.restAPI.info("Sitemap SSE subscription created: \(subscriptionId, privacy: .public)")

                let eventStream = try await service.openHABSitemapWidgetEventsRaw(
                    subscriptionid: subscriptionId,
                    sitemap: target.sitemap,
                    pageId: target.pageId
                )

                broadcast(.connected)
                backoff = 1 // Reset backoff on successful connection
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
                    if let message = parse(sse) {
                        broadcast(.event(message))
                    }
                }

                // Stream ended unexpectedly; trigger reconnect.
                throw URLError(.networkConnectionLost)
            } catch is CancellationError {
                return
            } catch {
                broadcast(.disconnected(mapError(error)))
                Logger.restAPI.error("Sitemap SSE error: \(error.localizedDescription, privacy: .public) – retrying in \(backoff, privacy: .public)s")
                try? await Task.sleep(for: .seconds(backoff))
                backoff = min(backoff * 2, maxBackoff)
            }
        }
    }

    /// Restarts the SSE connection if no events have been received for 30 seconds.
    /// The server sends ALIVE events every ~10 seconds, so 30 seconds without any
    /// event indicates a silently dead connection (e.g. after a server restart).
    private func checkAliveWatchdog() {
        guard Date.now.timeIntervalSince(lastEventTime) > 30 else { return }
        Logger.restAPI.warning("Sitemap SSE watchdog: no events for 30s, reconnecting")
        restartListeningIfPossible()
    }

    private func broadcast(_ msg: StreamOutput<SitemapEventMessage>) {
        continuations.values.forEach { $0.yield(msg) }
    }

    private func parse(_ sse: ServerSentEvent) -> SitemapEventMessage? {
        if let event = sse.event?.lowercased(), event == "alive" {
            Logger.restAPI.debug("Sitemap SSE alive event")
            return .alive
        }

        guard let raw = sse.data else { return nil }
        Logger.restAPI.debug("Sitemap SSE raw event: \(raw, privacy: .public)")
        let data = Data(raw.utf8)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let type = json["TYPE"] as? String {
            switch type {
            case "ALIVE":
                Logger.restAPI.debug("Sitemap SSE ALIVE event (TYPE)")
                return .alive
            case "SITEMAP_CHANGED":
                Logger.restAPI.info("Sitemap SSE SITEMAP_CHANGED event")
                return .sitemapChanged(
                    sitemap: json["sitemapName"] as? String,
                    pageId: json["pageId"] as? String
                )
            default:
                break
            }
        }

        if let decoded = try? jsonDecoder.decode(Components.Schemas.SitemapWidgetEvent.self, from: data),
           let event = OpenHABSitemapWidgetEvent(decoded) {
            Logger.restAPI.debug("Sitemap SSE widget event decoded: \(event.widgetId.orEmpty, privacy: .public)")
            return .widget(event)
        }

        return .unknown(raw: raw)
    }

    private func mapError(_ error: any Error) -> any Error {
        if let error = error as? SitemapSseError {
            return error
        }
        if let clientError = error as? OpenAPIRuntime.ClientError,
           clientError.response?.status.code == 404 {
            return SitemapSseError.unsupported
        }
        return error
    }
}
