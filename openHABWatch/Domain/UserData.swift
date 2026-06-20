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

import CommonUI
import Foundation
import OpenHABCore
import os.log
import SwiftUI

@MainActor
@Observable
final class UserData {
    static let shared = UserData()

    var widgets: [OpenHABWidget] = []
    var showAlert = false
    var errorDescription = ""
    var showCertificateAlert = false
    var certificateErrorDescription = ""
    var isLoadingSitemap = false

    // Cache last successful widgets to prevent empty state during reconnections
    private var cachedWidgets: [OpenHABWidget] = []
    private var currentlyLoadingSitemap: String?
    private var lastObservedConnectionURL: String?
    /// Incremented each time a new pageHandlingTask is created. The task captures its own
    /// generation at creation time and only clears shared state when the generation still matches,
    /// preventing a completing old task from wiping out a newly started task for the same sitemap.
    private var taskGeneration = 0

    // @ObservationIgnored prevents the @Observable macro from generating @MainActor-isolated
    // backing storage, keeping these as plain stored properties that deinit can cancel.
    @ObservationIgnored private nonisolated(unsafe) var pageHandlingTask: Task<Void, Never>?
    @ObservationIgnored private nonisolated(unsafe) var networkObservationTask: Task<Void, Never>?
    @ObservationIgnored private nonisolated(unsafe) var haveContextObservationTask: Task<Void, Never>?
    @ObservationIgnored private nonisolated(unsafe) var sitemapObservationTask: Task<Void, Never>?
    @ObservationIgnored private nonisolated(unsafe) var connectionConfigObservationTask: Task<Void, Never>?
    // nonisolated(unsafe): [any NSObjectProtocol] is not Sendable; without this the compiler
    // rejects the deinit removeObserver call, yet also warns that the annotation has no effect —
    // a known Swift diagnostics contradiction; the annotation IS required for deinit access.
    @ObservationIgnored private nonisolated(unsafe) var notificationObservers: [any NSObjectProtocol] = []
    var isPolling = false

    var openHABSitemapPage: OpenHABPage?
    var currentClientDelegate: HTTPClientDelegate?

    init(preview: Bool = false) {
        #if DEBUG
        if preview {
            let data = PreviewConstants.sitemapJson
            do {
                let sitemapPage = try data.decoded(as: Components.Schemas.PageDTO.self)
                openHABSitemapPage = OpenHABPage(sitemapPage)
                widgets = openHABSitemapPage?.widgets ?? []
                decorateWidgetsWithSendCommand(widgets)
            } catch {
                Logger.userData.error("Should not throw \(error.localizedDescription)")
            }
        }
        #endif
    }

    /// Initializes UserData for a linked page navigation
    init(linkedPage: OpenHABPage) {
        // Use the pageId directly from the linkedPage object
        let extractedPageId = linkedPage.pageId

        Logger.userData.info("Initializing UserData for linked page: '\(linkedPage.title)' with pageId: '\(extractedPageId)', link: '\(linkedPage.link)'")

        setupNotificationObservers()

        // Assign to pageHandlingTask so stopLongPolling() can cancel this setup task
        // before it runs if the view disappears while it is still queued on the main actor
        // (e.g. rapid navigation). Without this, stopLongPolling() finds pageHandlingTask == nil,
        // cancels nothing, and the task later starts an uncancellable long-poll that leaks the
        // UserData instance via a retain cycle.
        pageHandlingTask = Task { @MainActor [weak self] in
            guard !Task.isCancelled, let self else { return }
            let sitemapName = AppSettings.shared.sitemapForWatch
            guard !sitemapName.isEmpty else {
                Logger.userData.error("Cannot load linked page: no sitemap configured")
                errorDescription = "No sitemap configured"
                showAlert = true
                return
            }
            Logger.userData.info("Starting page handling for sitemap: \(sitemapName), pageId: \(extractedPageId)")
            // Clear pageHandlingTask before calling startPageHandling so it sees nil and
            // takes the clean "no running task" path rather than cancelling itself.
            pageHandlingTask = nil
            startPageHandling(sitemapName: sitemapName, pageId: extractedPageId, force: true)
        }
    }

    init() {
        setupNotificationObservers()
        observeHaveReceivedAppContext()
        observeSitemapForWatch()
        observeConnectionConfigs()

        networkObservationTask = Task { [weak self] in
            // Obtain the stream without capturing self, so self is not held across suspensions.
            let stream = await NetworkTracker.shared.activeConnectionStream()
            for await connection in stream {
                guard let self else { break }
                handleConnectionEvent(connection)
            }
        }
    }

    /// Replicates the old $haveReceivedAppContext.filter { $0 }.sink behavior.
    /// Fires immediately if the value is already true, then watches for transitions to true.
    private func observeHaveReceivedAppContext() {
        haveContextObservationTask = Task { @MainActor [weak self] in
            if AppSettings.shared.haveReceivedAppContext {
                await self?.updateNetwork()
            }
            var previous = AppSettings.shared.haveReceivedAppContext
            while !Task.isCancelled {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    withObservationTracking {
                        _ = AppSettings.shared.haveReceivedAppContext
                    } onChange: {
                        continuation.resume()
                    }
                }
                guard let self else { break }
                let current = AppSettings.shared.haveReceivedAppContext
                if current, !previous {
                    await updateNetwork()
                }
                previous = current
            }
        }
    }

    /// True debounce equivalent of $sitemapForWatch.removeDuplicates().debounce(0.3).sink.
    /// Triggers on the initial value (no dropFirst) to start page handling on cold start.
    /// Each detected change cancels the pending timer and starts a fresh 300ms one, so only
    /// the final change in a rapid burst triggers startPageHandling.
    private func observeSitemapForWatch() {
        sitemapObservationTask = Task { @MainActor [weak self] in
            let initial = AppSettings.shared.sitemapForWatch
            var previous = initial
            var debounceTask: Task<Void, Never>?
            if !initial.isEmpty {
                debounceTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled, let self else { return }
                    let force = currentlyLoadingSitemap != initial
                    Logger.userData.debug("Sitemap observer initial (debounced): \(initial), force: \(force)")
                    startPageHandling(sitemapName: initial, force: force)
                }
            }
            while !Task.isCancelled {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    withObservationTracking {
                        _ = AppSettings.shared.sitemapForWatch
                    } onChange: {
                        continuation.resume()
                    }
                }
                guard let self, !Task.isCancelled else { break }
                let current = AppSettings.shared.sitemapForWatch
                guard current != previous else { continue }
                previous = current
                debounceTask?.cancel()
                debounceTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled, let self else { return }
                    guard !current.isEmpty else {
                        Logger.userData.debug("Sitemap observer: empty sitemap, ignoring")
                        return
                    }
                    let isDifferentSitemap = currentlyLoadingSitemap != current
                    let currentlySitemap = currentlyLoadingSitemap ?? "nil"
                    Logger.userData.debug("Sitemap change detected - current: \(currentlySitemap), new: \(current), force: \(isDifferentSitemap)")
                    startPageHandling(sitemapName: current, force: isDifferentSitemap)
                }
            }
            debounceTask?.cancel()
        }
    }

    /// True debounce equivalent of $localConnectionConfig.combineLatest($remoteConnectionConfig)
    /// .removeDuplicates{url}.debounce(0.5).sink.
    /// Triggers on initial values (no dropFirst) to cover cold start.
    /// Each detected URL change cancels the pending timer and starts a fresh 500ms one.
    private func observeConnectionConfigs() {
        connectionConfigObservationTask = Task { @MainActor [weak self] in
            var prevLocalURL = AppSettings.shared.localConnectionConfig?.url
            var prevRemoteURL = AppSettings.shared.remoteConnectionConfig?.url
            var debounceTask: Task<Void, Never>? = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled, let self else { return }
                await updateNetwork()
            }
            while !Task.isCancelled {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    withObservationTracking {
                        _ = AppSettings.shared.localConnectionConfig
                        _ = AppSettings.shared.remoteConnectionConfig
                    } onChange: {
                        continuation.resume()
                    }
                }
                guard let self, !Task.isCancelled else { break }
                let localURL = AppSettings.shared.localConnectionConfig?.url
                let remoteURL = AppSettings.shared.remoteConnectionConfig?.url
                guard localURL != prevLocalURL || remoteURL != prevRemoteURL else { continue }
                prevLocalURL = localURL
                prevRemoteURL = remoteURL
                debounceTask?.cancel()
                debounceTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled, let self else { return }
                    await updateNetwork()
                }
            }
            debounceTask?.cancel()
        }
    }

    /// Sets up notification observers for certificate validation and changes
    private func setupNotificationObservers() {
        let evaluateServerTrust = NotificationCenter.default.addObserver(
            forName: .evaluateServerTrust,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let summary = notification.userInfo?["summary"] as? String,
                  let domain = notification.userInfo?["domain"] as? String,
                  let delegate = notification.object as? HTTPClientDelegate else { return }
            DispatchQueue.main.async {
                self.certificateErrorDescription = String(format: String(localized: "ssl_certificate_invalid", comment: ""), summary, domain)
                self.currentClientDelegate = delegate
                self.showCertificateAlert = true
            }
        }

        let evaluateCertificateMismatch = NotificationCenter.default.addObserver(
            forName: .evaluateCertificateMismatch,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let summary = notification.userInfo?["summary"] as? String,
                  let domain = notification.userInfo?["domain"] as? String,
                  let delegate = notification.object as? HTTPClientDelegate else { return }
            DispatchQueue.main.async {
                self.certificateErrorDescription = String(format: String(localized: "ssl_certificate_no_match", comment: ""), summary, domain)
                self.currentClientDelegate = delegate
                self.showCertificateAlert = true
            }
        }

        let acceptedCertificatesChanged = NotificationCenter.default.addObserver(
            forName: .acceptedServerCertificatesChanged,
            object: nil,
            queue: nil
        ) { _ in
            Task { @MainActor in
                await NetworkTracker.shared.restartTracking()
            }
        }

        notificationObservers = [evaluateServerTrust, evaluateCertificateMismatch, acceptedCertificatesChanged]
    }

    /// Handles a single connection-change event. Called once per value emitted by the network stream;
    /// returns immediately so the task loop can release self between events.
    private func handleConnectionEvent(_ activeConnection: ConnectionInfo?) {
        guard let activeConnection else {
            if let lastObservedConnectionURL {
                Logger.userData.info("Network connection became unavailable (previous: \(lastObservedConnectionURL, privacy: .public))")
                self.lastObservedConnectionURL = nil
            } else {
                Logger.userData.debug("Network connection stream emitted nil (no active connection)")
            }
            return
        }

        if lastObservedConnectionURL != activeConnection.configuration.url {
            if let previousConnectionURL = lastObservedConnectionURL {
                Logger.userData.info("Network connection changed: \(previousConnectionURL, privacy: .public) -> \(activeConnection.configuration.url, privacy: .public)")
            } else {
                Logger.userData.info("Network connection became available: \(activeConnection.configuration.url, privacy: .public)")
            }
            lastObservedConnectionURL = activeConnection.configuration.url
        } else {
            Logger.userData.debug("Network connection still active: \(activeConnection.configuration.url, privacy: .public)")
        }

        if !AppSettings.shared.haveReceivedAppContext {
            AppMessageService.singleton.requestApplicationContext()
            errorDescription = String(localized: "settings_not_received", comment: "")
            showAlert = true
            return
        }

        AppSettings.shared.openHABRootUrl = activeConnection.configuration.url
        AppSettings.shared.openHABVersion = activeConnection.version

        let sitemapName = AppSettings.shared.sitemapForWatch
        if !sitemapName.isEmpty {
            if let task = pageHandlingTask, !task.isCancelled {
                if currentlyLoadingSitemap == sitemapName {
                    Logger.userData.debug("Page handling task already running for correct sitemap: \(sitemapName)")
                } else {
                    Logger.userData.debug("Page handling task for wrong sitemap, forcing reload: \(sitemapName)")
                    startPageHandling(sitemapName: sitemapName, force: true)
                }
            } else {
                Logger.userData.debug("Starting page handling for sitemap: \(sitemapName) after network became available")
                startPageHandling(sitemapName: sitemapName, force: false)
            }
        }
    }

    func updateNetwork() async {
        let connections = [
            AppSettings.shared.localConnectionConfig,
            AppSettings.shared.remoteConnectionConfig
        ].compactMap(\.self)

        guard !connections.isEmpty else {
            Logger.userData.warning("No connections defined")
            return
        }
        await NetworkTracker.shared.startTracking(connectionConfigurations: connections)
    }

    func startPageHandling(sitemapName: String, pageId: String = "", force: Bool = false) {
        Logger.userData.debug("startPageHandling called - sitemap: \(sitemapName), pageId: \(pageId), force: \(force)")

        // Handle concurrent loads based on force parameter
        if let task = pageHandlingTask, !task.isCancelled {
            if currentlyLoadingSitemap == sitemapName {
                if force {
                    Logger.userData.debug("Cancelling existing task for same sitemap (force=true)")
                    task.cancel()
                } else {
                    Logger.userData.debug("Same sitemap already loading and force=false, skipping")
                    return
                }
            } else {
                Logger.userData.debug("Cancelling existing task for different sitemap")
                task.cancel()
            }
        }
        currentlyLoadingSitemap = sitemapName
        taskGeneration += 1
        let capturedGeneration = taskGeneration

        pageHandlingTask = Task {
            defer {
                // Use the captured generation rather than sitemap name: a force-refresh of the same
                // sitemap would set currentlyLoadingSitemap to the same string, so the name check
                // would incorrectly clear the new task's slot when the old task finishes.
                if taskGeneration == capturedGeneration {
                    Logger.userData.debug("Clearing page handling task for: \(sitemapName)")
                    pageHandlingTask = nil
                    currentlyLoadingSitemap = nil
                }
            }

            do {
                isLoadingSitemap = true

                // Always ensure tracking is running before waiting.
                // startTracking is idempotent for unchanged active configurations.
                await updateNetwork()

                var connectionInfo = await NetworkTracker.shared.activeConnection
                if connectionInfo == nil {
                    connectionInfo = await waitForActiveConnection()
                }

                if connectionInfo == nil {
                    Logger.userData.warning("No active connection after 20 s; restarting network tracking once and retrying")
                    await updateNetwork()
                    connectionInfo = await waitForActiveConnection()
                }

                guard let connectionInfo else {
                    Logger.userData.error("No active connection available after timeout")
                    errorDescription = String(localized: "settings_not_received", comment: "")
                    showAlert = true
                    isLoadingSitemap = false
                    return
                }

                Logger.userData.debug("Using connection: \(connectionInfo.configuration.url)")
                Logger.userData.debug("Starting page stream for sitemap: \(sitemapName)")

                for try await event in SitemapPageLoader.stream(
                    sitemapName: sitemapName,
                    pageId: pageId,
                    connectionInfo: connectionInfo
                ) {
                    try Task.checkCancellation()
                    // Always clear loading state on the first event, even if the server
                    // returned no page data on the initial fetch.
                    isLoadingSitemap = false
                    let page: OpenHABPage? = switch event {
                    case let .initialFetch(page): page
                    case let .longPoll(page, _): page
                    }
                    guard let page else { continue }
                    // Only update page object when title changes to avoid
                    // firing objectWillChange and resetting scroll position
                    if openHABSitemapPage?.title != page.title {
                        openHABSitemapPage = page
                    }
                    let newWidgets = page.widgets
                    updateWidgets(with: newWidgets)
                    if !newWidgets.isEmpty {
                        cachedWidgets = newWidgets
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                Logger.userData.error("Page handling failed for sitemap '\(sitemapName)': \(error.localizedDescription)")

                // Use cached widgets if available instead of clearing completely
                if cachedWidgets.isEmpty {
                    Logger.userData.warning("No cached widgets available, showing empty state")
                    widgets = []
                } else {
                    widgets = cachedWidgets
                    Logger.userData.info("Using \(self.cachedWidgets.count) cached widgets during connection failure")
                }
                errorDescription = error.localizedDescription
                showAlert = true
                isLoadingSitemap = false
                // Note: NetworkTracker will automatically handle failover to remote if local fails
            }
        }
    }

    private func waitForActiveConnection(timeoutSeconds: Double = 20) async -> ConnectionInfo? {
        await withTaskGroup(of: ConnectionInfo?.self) { group in
            group.addTask { await NetworkTracker.shared.waitForActiveConnection() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                return nil
            }
            defer { group.cancelAll() }
            return await group.next() ?? nil
        }
    }

    func stopLongPolling() {
        pageHandlingTask?.cancel()
        pageHandlingTask = nil
        isPolling = false
        isLoadingSitemap = false
    }

    func sendCommand(_ item: OpenHABItem?, command: String?) async {
        guard let item, let command else { return }
        let sitemapName = AppSettings.shared.sitemapForWatch
        let pageId = openHABSitemapPage?.pageId ?? ""
        let sourcePrefix = (!sitemapName.isEmpty && !pageId.isEmpty) ? "org.openhab.ui.basic$\(sitemapName):\(pageId)" : nil
        do {
            try await NetworkTracker.shared.send(to: item, command: command, sourcePrefix: sourcePrefix, deviceId: AppSettings.deviceId)
        } catch {
            Logger.userData.error("Failed to send command '\(command)' to '\(item.name)': \(error.localizedDescription)")
        }
    }

    // swiftlint:disable:next async_without_await
    func refreshUrl(force: Bool = false) async {
        guard AppSettings.shared.haveReceivedAppContext, !AppSettings.shared.sitemapForWatch.isEmpty else { return }

        showAlert = false
        startPageHandling(sitemapName: AppSettings.shared.sitemapForWatch, force: force)
    }

    /// Updates existing widget instances instead of replacing them to preserve @ObservedObject references
    private func updateWidgets(with newWidgets: [OpenHABWidget]) {
        let existingWidgetsMap = Dictionary(uniqueKeysWithValues: widgets.map { ($0.widgetId, $0) })

        // Check if the widget list structure changed (count, order, or IDs)
        let structureChanged = widgets.count != newWidgets.count
            || !zip(widgets, newWidgets).allSatisfy { $0.widgetId == $1.widgetId }

        for newWidget in newWidgets {
            if let existingWidget = existingWidgetsMap[newWidget.widgetId] {
                // Update existing widget's properties in place — this triggers
                // per-row re-renders via @ObservedObject without rebuilding the list
                existingWidget.label = newWidget.label
                existingWidget.type = newWidget.type
                existingWidget.icon = newWidget.icon
                existingWidget.state = newWidget.state
                existingWidget.text = newWidget.text
                existingWidget.inputHint = newWidget.inputHint
                existingWidget.encoding = newWidget.encoding
                existingWidget.isLeaf = newWidget.isLeaf
                existingWidget.item = newWidget.item
                existingWidget.iconColor = newWidget.iconColor
                existingWidget.labelcolor = newWidget.labelcolor
                existingWidget.valuecolor = newWidget.valuecolor
                existingWidget.url = newWidget.url
                existingWidget.period = newWidget.period
                existingWidget.service = newWidget.service
                existingWidget.legend = newWidget.legend
                existingWidget.refresh = newWidget.refresh
                existingWidget.height = newWidget.height
                existingWidget.forceAsItem = newWidget.forceAsItem
                existingWidget.minValue = newWidget.minValue
                existingWidget.maxValue = newWidget.maxValue
                existingWidget.step = newWidget.step
                existingWidget.pattern = newWidget.pattern
                existingWidget.unit = newWidget.unit
                existingWidget.switchSupport = newWidget.switchSupport
                existingWidget.mappings = newWidget.mappings
                existingWidget.widgets = newWidget.widgets
                existingWidget.linkedPage = newWidget.linkedPage
                existingWidget.visibility = newWidget.visibility
                existingWidget.staticIcon = newWidget.staticIcon
                existingWidget.labelSource = newWidget.labelSource
                existingWidget.releaseOnly = newWidget.releaseOnly
                existingWidget.row = newWidget.row
                existingWidget.column = newWidget.column
                existingWidget.releaseCommand = newWidget.releaseCommand
                existingWidget.command = newWidget.command
                existingWidget.stateless = newWidget.stateless
                existingWidget.yAxisDecimalPattern = newWidget.yAxisDecimalPattern
            }
        }

        // Wire sendCommand closures directly to UserData rather than copying
        // from the page's decorated widgets. The page object is a local variable
        // that gets deallocated after each poll cycle (when the title doesn't
        // change), which kills the [weak page] closures set by
        // decorateWithSendCommand. By capturing [weak self] (UserData) instead,
        // the closures remain alive for the lifetime of the view hierarchy.
        let allWidgets = structureChanged
            ? newWidgets.map { existingWidgetsMap[$0.widgetId] ?? $0 }
            : widgets
        decorateWidgetsWithSendCommand(allWidgets)

        // Only reassign the array when the list structure actually changed
        // (widgets added, removed, or reordered). This avoids a full
        // ScrollView rebuild that resets the scroll position.
        if structureChanged {
            widgets = allWidgets
        }
    }

    /// Sets sendCommand closures on widgets that go directly to UserData,
    /// bypassing the OpenHABPage closure chain and its weak-reference lifetime issues.
    private func decorateWidgetsWithSendCommand(_ widgets: [OpenHABWidget]) {
        for widget in widgets {
            widget.sendCommand = { [weak self] item, command in
                Task { await self?.sendCommand(item, command: command) }
            }
        }
    }

    deinit {
        // pageHandlingTask strongly captures self, creating a retain cycle that keeps self alive
        // until the task finishes. For linked-page instances the cycle is broken by stopLongPolling()
        // (called from .onDisappear), which cancels the task and nils pageHandlingTask; by the time
        // deinit runs, the task has already completed and pageHandlingTask is nil. The cancel() call
        // here is therefore a no-op in the normal path but harmless as a safety net.
        pageHandlingTask?.cancel()
        networkObservationTask?.cancel()
        haveContextObservationTask?.cancel()
        sitemapObservationTask?.cancel()
        connectionConfigObservationTask?.cancel()
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
