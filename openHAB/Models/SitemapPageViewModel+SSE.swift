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

import OpenHABCore
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "org.openhab.app", category: "SitemapPageViewModel")

@MainActor
extension SitemapPageViewModel {
    func shouldUseSSE() -> Bool {
        ssePreferred && serverProperties?.hasSseSupport() == true
    }

    func startSSE(sitemap: String, pageId: String) async {
        sseConnected = false
        sseNeedsRefreshOnReconnect = false
        sseStreamTask?.cancel()

        logger.info("Starting sitemap SSE for \(sitemap, privacy: .public)/\(pageId, privacy: .public)")
        await sitemapEventStream.startMonitoringNetworkIfNeeded(initialConnection: networkTracker.activeConnection)
        let stream = await sitemapEventStream.stream(sitemap: sitemap, pageId: pageId)

        sseStreamTask = Task { [weak self] in
            guard let self else { return }
            for await msg in stream {
                guard !Task.isCancelled else { break }
                handleSseOutput(msg)
            }
        }
    }

    func handleSseOutput(_ msg: StreamOutput<SitemapEventMessage>) {
        switch msg {
        case .connected:
            logger.info("Sitemap SSE connected")
            sseConnected = true
            ssePreferred = true
            isUpdating = false
            if sseNeedsRefreshOnReconnect {
                sseNeedsRefreshOnReconnect = false
                logger.info("Sitemap SSE reconnected, refreshing page to recover missed events")
                startPageHandling(
                    forceRestart: true,
                    reason: "sse-reconnected",
                    preserveCurrentContent: true,
                    recreateService: false
                )
            }
        case let .disconnected(error):
            logger.warning("Sitemap SSE disconnected: \(error?.localizedDescription ?? "nil", privacy: .public)")
            isUpdating = false
            guard shouldFallbackToLongPolling(after: error) else {
                sseNeedsRefreshOnReconnect = true
                return
            }
            startLongPollingFallback(error)
        case let .event(message):
            handleSseMessage(message)
        }
    }

    func shouldFallbackToLongPolling(after error: (any Error)?) -> Bool {
        guard let error else { return !sseConnected }
        if let sseError = error as? SitemapSseError {
            switch sseError {
            case .unsupported:
                return true
            }
        }
        return !sseConnected
    }

    func startLongPollingFallback(_ error: (any Error)?) {
        ssePreferred = false
        sseStreamTask?.cancel()
        sseStreamTask = nil
        Task {
            await sitemapEventStream.stop()
        }

        if let error {
            logger.warning("SSE unavailable (\(error.localizedDescription, privacy: .public)), falling back to long polling")
        } else {
            logger.warning("SSE unavailable, falling back to long polling")
        }
        startPageHandling(
            forceRestart: true,
            reason: "sse-fallback",
            preserveCurrentContent: true,
            recreateService: false
        )
    }

    func handleSseMessage(_ message: SitemapEventMessage) {
        switch message {
        case .alive:
            return
        case let .sitemapChanged(sitemap, pageId):
            logger.info("SSE sitemap changed \(sitemap.orEmpty, privacy: .public)/\(pageId.orEmpty, privacy: .public)")
            startPageHandling(
                forceRestart: true,
                reason: "sse-sitemap-changed",
                preserveCurrentContent: true,
                recreateService: false
            )
        case let .widget(event):
            applySseWidgetEvent(event)
        case let .unknown(raw):
            logger.debug("SSE unknown event: \(raw, privacy: .public)")
        }
    }

    func applySseWidgetEvent(_ event: OpenHABSitemapWidgetEvent) {
        guard let currentPage else { return }
        guard let widgetId = event.widgetId else { return }

        if widgetId == pageId, let label = event.label {
            objectWillChange.send()
            currentPage.title = label
            return
        }

        switch currentPage.apply(event: event) {
        case .unchanged:
            isUpdating = false
        case .applied:
            objectWillChange.send()
            widgetUpdateVersions[widgetId, default: 0] += 1
            _ = clearSyncedSliderOverrides(using: currentPage.widgets)
            rebuildRowInputs()
            isUpdating = false
        case .requiresPageReload:
            logger.info("SSE widget \(widgetId, privacy: .public) requires full sitemap reload")
            startPageHandling(
                forceRestart: true,
                reason: "sse-widget-reload-required",
                preserveCurrentContent: true,
                recreateService: false
            )
        case .notFound:
            logger.info("SSE widget \(widgetId, privacy: .public) not found, reloading sitemap")
            startPageHandling(
                forceRestart: true,
                reason: "sse-widget-missing",
                preserveCurrentContent: true,
                recreateService: false
            )
        }
    }
}
