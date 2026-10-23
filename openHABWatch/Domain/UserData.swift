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
import CommonUI
import Foundation
import OpenHABCore
import os.log
import SwiftUI

@MainActor
final class UserData: ObservableObject {
    static let shared = UserData()

    @Published var widgets: [OpenHABWidget] = [] {
        didSet { refreshVisibleWidgets() }
    }

    /// The widgets the page shows, after hiding the invisible ones.
    @Published private(set) var visibleWidgets: [OpenHABWidget] = []
    /// The title the page shows. Kept apart from `openHABSitemapPage`, whose title changes in place.
    @Published private(set) var pageTitle: String?
    @Published var showAlert = false
    @Published var errorDescription = ""
    @Published var showCertificateAlert = false
    @Published var certificateErrorDescription = ""
    @Published var isLoadingSitemap = false

    // Cache last successful widgets to prevent empty state during reconnections
    private var cachedWidgets: [OpenHABWidget] = []
    private var currentlyLoadingSitemap: String?
    /// Page ID of a linked page, `nil` for the root page.
    private var linkedPageId: String?
    private var lastObservedConnectionURL: String?
    /// Incremented each time a new pageHandlingTask is created. The task captures its own
    /// generation at creation time and only clears shared state when the generation still matches,
    /// preventing a completing old task from wiping out a newly started task for the same sitemap.
    private var taskGeneration = 0
    /// Set while the page is off screen or the app is in the background. Page handling stays
    /// stopped then, so only the visible page follows the server, and only in the foreground.
    private var isPaused = false

    private var pageHandlingTask: Task<Void, Never>?
    private let sitemapEventStream = SitemapEventStream()
    private var eventsDuringReload = SitemapEventReplayLog()
    private var networkObservationTask: Task<Void, Never>?
    // nonisolated(unsafe): accessed only from deinit, which is the last operation on the instance.
    private nonisolated(unsafe) var notificationObservers: [any NSObjectProtocol] = []
    @Published var isPolling = false

    @Published var openHABSitemapPage: OpenHABPage? {
        didSet { showTitle(openHABSitemapPage?.title) }
    }

    var currentClientDelegate: HTTPClientDelegate?

    private var cancellables = Set<AnyCancellable>()

    init(preview: Bool = false) {
        #if DEBUG
        if preview {
            let data = PreviewConstants.sitemapJson
            do {
                let sitemapPage = try data.decoded(as: Components.Schemas.PageDTO.self)
                openHABSitemapPage = OpenHABPage(sitemapPage)
                widgets = openHABSitemapPage?.widgets ?? []
                decorateWidgetsWithSendCommand(widgets)
                // Property observers don't run in an initializer.
                refreshVisibleWidgets()
                showTitle(openHABSitemapPage?.title)
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
        linkedPageId = extractedPageId

        Logger.userData.info("Initializing UserData for linked page: '\(linkedPage.title)' with pageId: '\(extractedPageId)', link: '\(linkedPage.link)'")

        setupNotificationObservers()

        // Assign to pageHandlingTask so pausePageHandling() can cancel this setup task
        // before it runs if the view disappears while it is still queued on the main actor
        // (e.g. rapid navigation). Without this, pausePageHandling() finds pageHandlingTask == nil,
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

        AppSettings.shared.$haveReceivedAppContext
            .removeDuplicates()
            .filter { $0 == true }
            .sink { [weak self] _ in
                Task {
                    await self?.updateNetwork()
                }
            }
            .store(in: &cancellables)

        // Observe sitemap changes - reload the sitemap when it changes
        // Note: We don't use .dropFirst() here because we need to catch the initial value
        // when the app context is first received from the iOS app on real devices
        AppSettings.shared.$sitemapForWatch
            .removeDuplicates()
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .sink { [weak self] newValue in
                guard !newValue.isEmpty else {
                    Logger.userData.debug("Sitemap observer: empty sitemap, ignoring")
                    return
                }
                Logger.userData.debug("Sitemap observer fired: \(newValue)")
                Task { @MainActor in
                    guard let self else { return }

                    // Only force restart if the sitemap name actually changed
                    let isDifferentSitemap = self.currentlyLoadingSitemap != newValue
                    Logger.userData.debug("Sitemap change detected - current: \(self.currentlyLoadingSitemap ?? "nil"), new: \(newValue), force: \(isDifferentSitemap)")

                    // Note: We don't check for active connection here because NetworkTracker
                    // can report false negatives (especially during long-polling on real devices).
                    // The observeNetworkChanges() function will handle retrying when network becomes available.
                    self.startPageHandling(sitemapName: newValue, force: isDifferentSitemap)
                }
            }
            .store(in: &cancellables)

        // Observe connection config changes and trigger on initial values (no dropFirst).
        // This covers cold start (persisted connections fire immediately on subscription)
        // and config updates (server URL changed on iPhone and synced via WC).
        AppSettings.shared.$localConnectionConfig
            .combineLatest(AppSettings.shared.$remoteConnectionConfig)
            .removeDuplicates { lhs, rhs in
                lhs.0?.url == rhs.0?.url && lhs.1?.url == rhs.1?.url
            }
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _, _ in
                Task { @MainActor in
                    await self?.updateNetwork()
                }
            }
            .store(in: &cancellables)

        networkObservationTask = Task { [weak self] in
            // Obtain the stream without capturing self, so self is not held across suspensions.
            // stateStream() is now a pure AsyncStream (no Combine). The loop re-runs on every
            // NetworkState change, not only when activeConnection changes, but handleConnectionEvent
            // no-ops on an unchanged URL so behavior is correct.
            let stream = await NetworkTracker.shared.stateStream()
            for await state in stream {
                guard let self else { break }
                handleConnectionEvent(state.activeConnection)
            }
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
        guard !isPaused else {
            Logger.userData.debug("Page handling is paused, starting when the page is visible again")
            return
        }

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
            let taskSitemapName = sitemapName
            defer {
                // Use the captured generation rather than sitemap name: a force-refresh of the same
                // sitemap would set currentlyLoadingSitemap to the same string, so the name check
                // would incorrectly clear the new task's slot when the old task finishes.
                if taskGeneration == capturedGeneration {
                    Logger.userData.debug("Clearing page handling task for: \(taskSitemapName)")
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
                let service = try OpenAPIService(
                    connectionConfiguration: connectionInfo.configuration,
                    serviceConfiguration: .longTerm
                )

                if SitemapUpdatePolicy.usesEvents(serverVersion: connectionInfo.version) {
                    let page = try await service.pollDataForPage(sitemapname: sitemapName, pageId: pageId, longPolling: false)
                    try Task.checkCancellation()
                    isLoadingSitemap = false
                    if let page {
                        show(page)
                    }
                    let eventPageId = [page?.pageId, pageId].compactMap(\.self).first { !$0.isEmpty } ?? sitemapName
                    guard await !followEvents(sitemapName: sitemapName, pageId: eventPageId, connectionInfo: connectionInfo) else {
                        return
                    }
                    Logger.userData.info("Sitemap events unavailable for \(taskSitemapName), falling back to long polling")
                }

                Logger.userData.debug("Starting long polling for sitemap: \(taskSitemapName)")
                for try await event in SitemapPageLoader.stream(
                    sitemapName: sitemapName,
                    pageId: pageId,
                    service: service
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
                    show(page)
                }
            } catch is CancellationError {
                return
            } catch {
                Logger.userData.error("Page handling failed for sitemap '\(taskSitemapName)': \(error.localizedDescription)")

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

    /// Follows the page again after `pausePageHandling()`, starting from a fresh snapshot of it.
    /// Does nothing unless paused, which includes the page's first appearance.
    func resumePageHandling() {
        guard isPaused else { return }
        isPaused = false
        let sitemapName = AppSettings.shared.sitemapForWatch
        guard !sitemapName.isEmpty else { return }
        startPageHandling(sitemapName: sitemapName, pageId: linkedPageId ?? "", force: true)
    }

    /// Stops following the page, including its event stream and pending reloads, while the page
    /// is off screen, e.g. under a pushed page or another tab, or the app is in the background.
    func pausePageHandling() {
        isPaused = true
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
        startPageHandling(sitemapName: AppSettings.shared.sitemapForWatch, pageId: linkedPageId ?? "", force: force)
    }

    /// Updates existing widget instances instead of replacing them to preserve @ObservedObject references
    private func updateWidgets(with newWidgets: [OpenHABWidget]) {
        let existingWidgetsMap = Dictionary(uniqueKeysWithValues: widgets.map { ($0.widgetId, $0) })

        // Check if the widget list structure changed (count, order, or IDs)
        let structureChanged = widgets.count != newWidgets.count
            || !zip(widgets, newWidgets).allSatisfy { $0.widgetId == $1.widgetId }
        var visibilityChanged = false

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
                // Keep the widgets on screen as the children, so an event applied through the
                // parent reaches them.
                existingWidget.widgets = newWidget.widgets.map { existingWidgetsMap[$0.widgetId] ?? $0 }
                existingWidget.linkedPage = newWidget.linkedPage
                visibilityChanged = visibilityChanged || existingWidget.visibility != newWidget.visibility
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

        // Only reassign the @Published array when the list structure actually
        // changed (widgets added, removed, or reordered). This avoids a full
        // ScrollView rebuild that resets the scroll position.
        if structureChanged {
            widgets = allWidgets
        } else if visibilityChanged {
            refreshVisibleWidgets()
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
        // until the task finishes. For linked-page instances the cycle is broken by pausePageHandling()
        // (called from .onDisappear), which cancels the task and nils pageHandlingTask; by the time
        // deinit runs, the task has already completed and pageHandlingTask is nil. The cancel() call
        // here is therefore a no-op in the normal path but harmless as a safety net.
        pageHandlingTask?.cancel()
        networkObservationTask?.cancel()
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}

// MARK: - Following the page

private extension UserData {
    /// Follows the page through the server's sitemap events until the task is cancelled. Returns
    /// `false` when the events aren't available, so the caller falls back to long polling.
    func followEvents(sitemapName: String, pageId: String, connectionInfo: ConnectionInfo) async -> Bool {
        await sitemapEventStream.startMonitoringNetworkIfNeeded(initialConnection: connectionInfo)
        let stream = await sitemapEventStream.stream(sitemap: sitemapName, pageId: pageId)
        var hasConnected = false
        var reloadTask: Task<Void, Never>?
        defer { reloadTask?.cancel() }
        // Reloads alongside the events, retrying until it succeeds, so a failed reload doesn't
        // leave missed changes on screen. A newer reload replaces a pending one.
        func reload() {
            reloadTask?.cancel()
            reloadTask = Task { await self.reloadPageUntilShown(sitemapName: sitemapName, pageId: pageId) }
        }

        for await output in stream {
            switch output {
            case .connected:
                Logger.userData.debug("Sitemap events connected for \(sitemapName)/\(pageId)")
                hasConnected = true
                // Fetch the page again: it catches what changed before the subscription existed,
                // or while the stream was down.
                reload()
            case let .disconnected(error):
                Logger.userData.warning("Sitemap events disconnected: \(error?.localizedDescription ?? "nil")")
                guard SitemapUpdatePolicy.shouldFallBackToLongPolling(after: error, hasConnected: hasConnected) else { continue }
                await sitemapEventStream.stop()
                return false
            case let .event(message):
                if needsPageReload(after: message, sitemapName: sitemapName) {
                    reload()
                }
            }
        }
        return true
    }

    /// Handles a sitemap event. Returns whether the page has to be fetched again.
    func needsPageReload(after message: SitemapEventMessage, sitemapName: String) -> Bool {
        switch message {
        case .alive:
            return false
        case .sitemapChanged:
            Logger.userData.info("Sitemap \(sitemapName) changed, reloading page")
            return true
        case let .widget(event):
            guard apply(event) else { return false }
            Logger.userData.info("Widget \(event.widgetId ?? "") needs the page reloaded")
            return true
        case let .unknown(raw):
            Logger.userData.debug("Unknown sitemap event: \(raw)")
            return false
        }
    }

    /// Applies a widget event to the widgets on screen, and keeps it for reloads in flight.
    /// Returns whether the page has to be fetched again.
    func apply(_ event: OpenHABSitemapWidgetEvent) -> Bool {
        eventsDuringReload.record(event)
        return applyToScreen(event)
    }

    func applyToScreen(_ event: OpenHABSitemapWidgetEvent) -> Bool {
        if let page = openHABSitemapPage, event.widgetId == page.pageId, let label = event.label {
            page.title = label
            showTitle(label)
            return false
        }
        let result = widgets.apply(event: event)
        if result == .applied, event.visibility != nil {
            refreshVisibleWidgets()
        }
        return SitemapUpdatePolicy.needsPageReload(after: result)
    }

    /// Fetches the page again until it is shown or the task is cancelled.
    func reloadPageUntilShown(sitemapName: String, pageId: String) async {
        var failedAttempts = 0
        while !Task.isCancelled {
            guard await !reloadPage(sitemapName: sitemapName, pageId: pageId) else { return }
            failedAttempts += 1
            try? await Task.sleep(for: SitemapUpdatePolicy.reloadRetryDelay(afterFailedAttempts: failedAttempts))
        }
    }

    /// Fetches the page again over whichever connection is active now, and shows it with the
    /// events that arrived meanwhile applied on top. Returns whether it was shown.
    func reloadPage(sitemapName: String, pageId: String) async -> Bool {
        let reload = eventsDuringReload.beginReload()
        let page: OpenHABPage?
        do {
            page = try await NetworkTracker.shared.pollDataForPage(sitemapname: sitemapName, pageId: pageId)
        } catch {
            eventsDuringReload.endReload(reload)
            if !(error is CancellationError) {
                Logger.userData.warning("Reloading page \(sitemapName)/\(pageId) failed: \(error.localizedDescription)")
            }
            return false
        }
        let missedEvents = eventsDuringReload.endReload(reload)
        guard !Task.isCancelled else { return false }
        guard let page else {
            Logger.userData.warning("Reloading page \(sitemapName)/\(pageId) returned no page")
            return false
        }
        show(page)
        // An event that needs another reload already asked for one when it first arrived.
        for event in missedEvents {
            _ = applyToScreen(event)
        }
        return true
    }

    /// Filters the widgets again. Visibility isn't published, so this runs whenever it may have
    /// changed. Only a different list is published, which keeps the scroll position otherwise.
    func refreshVisibleWidgets() {
        let visible = sitemapVisibleWidgets(widgets)
        guard !visible.elementsEqual(visibleWidgets, by: ===) else { return }
        visibleWidgets = visible
    }

    func showTitle(_ title: String?) {
        guard pageTitle != title else { return }
        pageTitle = title
    }

    func show(_ page: OpenHABPage) {
        // Only update page object when title changes to avoid
        // publishing a change and resetting scroll position
        if openHABSitemapPage?.title != page.title {
            openHABSitemapPage = page
        }
        updateWidgets(with: page.widgets)
        if !page.widgets.isEmpty {
            cachedWidgets = page.widgets
        }
    }
}
