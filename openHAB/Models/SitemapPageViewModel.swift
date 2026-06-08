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

@preconcurrency import Combine
import OpenHABCore
import os.log
import SwiftUI
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "org.openhab.app", category: "SitemapPageViewModel")

@MainActor
class SitemapPageViewModel: ObservableObject {
    @Published var currentPage: OpenHABPage?
    @Published var searchText = "" {
        didSet {
            rebuildRowInputs()
        }
    }

    @Published var error: (any LocalizedError)?
    @Published var isLoading = true
    @Published var isUpdating = false
    @Published var openHABRootUrl: String?
    @Published var showSearchField = false
    @Published private(set) var commandStates: [String: WidgetCommandLifecycleState] = [:]
    @Published private(set) var trackerStatus: NetworkStatus = .stopped
    @Published private(set) var widgetUpdateVersions: [String: Int] = [:]
    @Published private(set) var rowInputs: [SitemapRowInput] = []
    @Published var navigationPath: [LinkedPageNavigation] = []

    let networkTracker = MainActorNetworkTracker.shared
    private var openAPIService: OpenAPIService?
    private var activeConnectionInfo: ConnectionInfo?
    private var pageHandlingTask: Task<Void, Never>?
    private var foregroundRefreshTask: Task<Void, Never>?
    private var connectionObserverTask: Task<Void, Never>?
    private var networkStatusObserverTask: Task<Void, Never>?
    private let commandDispatcher = WidgetCommandDispatcher()
    private var defaultSitemap = ""
    private var defaultSitemapLabel = ""
    private var fallbackTitle = ""
    @Published var pageId = ""
    private var isLinkedPage = false
    private var pageNetworkStatus: NetworkStatus?
    private var pageNetworkStatusAvailable = false
    private var activePageHandlingKey: String?
    private var activePageHandlingID: UUID?
    private var commandStateResetTasks: [String: Task<Void, Never>] = [:]
    private var commandStateVersions: [String: Int] = [:]
    private var queuedCommands: [String: QueuedCommand] = [:]
    private var rowWidgetIndex: [RowID: OpenHABWidget] = [:]
    private var previousBuildRenderKeys: [WidgetRenderKey] = []
    private var previousBuildRowIDs: [RowID] = []
    private var sliderValueOverrides: [String: Double] = [:]
    private var sliderOverrideResetTasks: [String: Task<Void, Never>] = [:]
    var lastForegroundRefreshAt: Date = .distantPast
    private var isPageVisibleForRefresh = false
    private var lastUIUpdateAt: Date = .distantPast
    private var coalescedLongPollUpdateCount = 0
    private var pendingLongPollPage: OpenHABPage?
    private var longPollDebounceTask: Task<Void, Never>?
    private var foregroundObserverTask: Task<Void, Never>?
    private var rowInputRebuildTask: Task<Void, Never>?

    var pageTitle: String {
        let title = currentPage?.title.labelValueTitle ?? ""

        if !title.isEmpty {
            return title
        }
        if !fallbackTitle.isEmpty {
            return fallbackTitle.labelValueTitle
        }
        if !defaultSitemapLabel.isEmpty {
            return defaultSitemapLabel.labelValueTitle
        }
        // SitemapPageView shows a redacted placeholder title when loading
        return ""
    }

    var isLinked: Bool {
        isLinkedPage
    }

    init() {
        loadSettings()
        startObservers()
    }

    init(pageUrl: String, title: String, pageId: String = "") {
        loadSettings()
        isLinkedPage = true
        startObservers()
        fallbackTitle = title
        defaultSitemapLabel = title

        // Set openHABRootUrl from current active connection for charts/images
        openHABRootUrl = networkTracker.activeConnection?.configuration.url

        // Extract pageId from URL if not provided
        if pageId.isEmpty {
            if let urlComponents = URLComponents(string: pageUrl),
               let extractedPageId = urlComponents.queryItems?.first(where: { $0.name == "sitemap" })?.value {
                self.pageId = extractedPageId
            } else if let lastPathComponent = URL(string: pageUrl)?.lastPathComponent {
                self.pageId = lastPathComponent
            }
        } else {
            self.pageId = pageId
        }
    }

    init(sitemapName: String, pageUrl: String, title: String, pageId: String) {
        loadSettings()
        defaultSitemap = sitemapName
        isLinkedPage = true
        startObservers()
        fallbackTitle = title
        defaultSitemapLabel = title
        self.pageId = pageId

        // Set openHABRootUrl from current active connection for charts/images
        openHABRootUrl = networkTracker.activeConnection?.configuration.url
    }

    /// Initializes the view model with a fixed set of widgets, without loading or polling
    init(pageUrl: String = "", title: String = "Preview Page", pageId: String = "", widgets: [OpenHABWidget]) {
        isLinkedPage = !pageUrl.isEmpty
        fallbackTitle = title
        self.pageId = pageId
        currentPage = OpenHABPage(
            pageId: pageId.isEmpty ? UUID().uuidString : pageId,
            title: title,
            link: pageUrl,
            leaf: false,
            widgets: widgets,
            icon: ""
        )
        rebuildRowInputs()
    }

    private func startObservers() {
        trackerStatus = networkTracker.status

        // Observe connection changes (skip initial value) — initial load is triggered by .task in the view.
        connectionObserverTask = Task { [weak self] in
            guard let tracker = self?.networkTracker else { return }
            for await connection in tracker.$activeConnection.values.dropFirst() {
                await MainActor.run { [weak self] in
                    self?.handleActiveConnectionChange(connection)
                }
            }
        }

        networkStatusObserverTask = Task { [weak self] in
            guard let tracker = self?.networkTracker else { return }
            for await status in tracker.$status.values {
                await MainActor.run { [weak self] in
                    self?.trackerStatus = status
                    if status == .connected {
                        self?.flushQueuedCommands()
                    }
                }
            }
        }

        // Linked pages are not covered by SitemapNavigationView's scenePhase observer.
        // Observe UIApplication.didBecomeActiveNotification directly — more reliable than
        // scenePhase environment propagation through NavigationLink destinations.
        if isLinkedPage {
            foregroundObserverTask = Task { [weak self] in
                let notifications = NotificationCenter.default.notifications(
                    named: UIApplication.didBecomeActiveNotification
                )
                for await _ in notifications {
                    await MainActor.run { [weak self] in
                        self?.refreshOnForeground()
                    }
                }
            }
        }
    }

    func rebuildRowInputs() {
        let pageKey = "\(defaultSitemap)|\(pageId)"
        let widgets = relevantWidgets
        rowInputRebuildTask?.cancel()
        rowInputRebuildTask = Task { [weak self, pageKey, widgets] in
            let result = await SitemapPageViewModel.buildRowInputs(pageKey: pageKey, widgets: widgets)
            await MainActor.run {
                guard let self, !Task.isCancelled else { return }
                self.applySnapshotRowInputBuildResult(result, widgets: widgets)
            }
        }
    }

    func widget(for rowID: RowID) -> OpenHABWidget? {
        rowWidgetIndex[rowID]
    }

    func widgetUpdateVersion(for widgetId: String) -> Int {
        widgetUpdateVersions[widgetId] ?? 0
    }

    func sliderOverrideValue(for itemname: String?) -> Double? {
        guard let itemname, !itemname.isEmpty else { return nil }
        return sliderValueOverrides[itemname]
    }

    func setSliderOverrideValue(_ value: Double, for itemname: String?) {
        guard let itemname, !itemname.isEmpty else { return }
        sliderOverrideResetTasks[itemname]?.cancel()
        sliderOverrideResetTasks[itemname] = nil
        objectWillChange.send()
        sliderValueOverrides[itemname] = value
    }

    @discardableResult
    func syncSliderOverridesWithServerState(for widgets: [OpenHABWidget]) -> Int {
        clearSyncedSliderOverrides(using: widgets)
    }

    deinit {
        connectionObserverTask?.cancel()
        networkStatusObserverTask?.cancel()
        foregroundObserverTask?.cancel()
        pageHandlingTask?.cancel()
        foregroundRefreshTask?.cancel()
        longPollDebounceTask?.cancel()
        commandStateResetTasks.values.forEach { $0.cancel() }
        commandStateResetTasks.removeAll()
        sliderOverrideResetTasks.values.forEach { $0.cancel() }
        sliderOverrideResetTasks.removeAll()
        rowInputRebuildTask?.cancel()
    }
}

@MainActor
extension SitemapPageViewModel {
    private static func buildRowInputs(pageKey: String,
                                       widgets: [OpenHABWidget],
                                       previousRenderKeys: [WidgetRenderKey] = [],
                                       previousInputs: [SitemapRowInput] = [],
                                       previousRowIDs: [RowID] = []) async -> SnapshotRowInputBuildResult {
        let snapshots = widgets.map { WidgetMappingSnapshot(widget: $0) }
        return await Task.detached(priority: .userInitiated) {
            SitemapRowInputSnapshotBuilder.buildIncrementally(
                pageKey: pageKey,
                widgets: snapshots,
                previousRenderKeys: previousRenderKeys,
                previousInputs: previousInputs,
                previousRowIDs: previousRowIDs
            )
        }.value
    }

    func loadSettings() {
        defaultSitemap = Preferences.shared.currentHomePreferences.defaultSitemap
        showSearchField = Preferences.shared.applicationPreferences.showSearchField
    }

    func markAppeared() {
        isPageVisibleForRefresh = true
    }

    func stopPageHandling() {
        isPageVisibleForRefresh = false
        pageHandlingTask?.cancel()
        pageHandlingTask = nil
        foregroundRefreshTask?.cancel()
        foregroundRefreshTask = nil
        longPollDebounceTask?.cancel()
        longPollDebounceTask = nil
        pendingLongPollPage = nil
        coalescedLongPollUpdateCount = 0
        activePageHandlingKey = nil
        activePageHandlingID = nil
    }

    func refreshOnForeground() {
        // Only refresh pages that are currently visible. Off-screen pages are marked not visible via
        // stopPageHandling() when they disappear; they restart via .task when re-shown.
        guard isPageVisibleForRefresh else { return }
        // Coalesce repeated .active transitions from scene/system churn.
        let now = Date()
        guard now.timeIntervalSince(lastForegroundRefreshAt) > 0.75 else { return }
        lastForegroundRefreshAt = now

        guard foregroundRefreshTask == nil else { return }
        logger.info("FG refresh: scheduled")
        foregroundRefreshTask = Task { [weak self] in
            self?.startPageHandling(
                forceRestart: true,
                reason: "scene-became-active",
                preserveCurrentContent: true,
                recreateService: true
            )
            await MainActor.run {
                self?.foregroundRefreshTask = nil
            }
        }
    }

    func startPageHandling(forceRestart: Bool = false,
                           reason: String = "manual",
                           preserveCurrentContent: Bool = false,
                           recreateService: Bool = false) {
        guard networkTracker.activeConnection != nil || networkTracker.status != .stopped else {
            logger.info("Deferring page load until NetworkTracker starts (reason: \(reason, privacy: .public))")
            error = nil
            if currentPage == nil {
                isLoading = true
            }
            isUpdating = false
            return
        }

        let requestedKey = "\(defaultSitemap)|\(pageId)"
        if !forceRestart,
           let activeTask = pageHandlingTask,
           !activeTask.isCancelled,
           activePageHandlingKey == requestedKey {
            logger.info("Skipping duplicate page handling start for \(requestedKey, privacy: .public), reason: \(reason, privacy: .public)")
            return
        }

        pageHandlingTask?.cancel()
        longPollDebounceTask?.cancel()
        longPollDebounceTask = nil
        pendingLongPollPage = nil
        lastUIUpdateAt = .distantPast
        coalescedLongPollUpdateCount = 0
        error = nil // Clear any previous errors when starting a new page handling session
        if preserveCurrentContent, currentPage != nil {
            isLoading = false
            isUpdating = true
        } else {
            isLoading = true // Show redacted view immediately
            isUpdating = false
        }

        let runID = UUID()
        activePageHandlingID = runID
        activePageHandlingKey = requestedKey

        logger.info("🚀 Starting page load and long polling flow (reason: \(reason, privacy: .public), run: \(runID.uuidString, privacy: .public), key: \(requestedKey, privacy: .public))")

        pageHandlingTask = Task {
            await runPageHandling(
                runID: runID,
                reason: reason,
                recreateService: recreateService
            )
        }
    }

    private func runPageHandling(runID: UUID,
                                 reason: String,
                                 recreateService: Bool) async {
        let pipelineStartedAt = Date()
        var diagnostics = SitemapInitialLoadMeasurement(
            reason: reason,
            isLinkedPage: isLinkedPage,
            hasCurrentPage: currentPage != nil,
            connectionWasReady: networkTracker.activeConnection != nil,
            pipelineStartedAt: pipelineStartedAt
        )

        defer {
            if activePageHandlingID == runID {
                pageHandlingTask = nil
                activePageHandlingID = nil
            }
        }

        do {
            guard await ensureSitemapAvailableForHandling() else {
                diagnostics.log(
                    status: "failed",
                    page: currentPage,
                    rowCount: rowInputs.count,
                    errorDescription: "No sitemap available"
                )
                return
            }

            diagnostics.beginConnectionSelection()
            guard let activeConnection = await waitForConnectionForHandling() else {
                diagnostics.log(
                    status: "failed",
                    page: currentPage,
                    rowCount: rowInputs.count,
                    errorDescription: "No active connection"
                )
                return
            }

            diagnostics.beginServiceSetup(connection: activeConnection.configuration)
            try setupServiceIfNeeded(activeConnection: activeConnection, forceRecreate: recreateService)

            if defaultSitemapLabel.isEmpty {
                diagnostics.beginLabelFetch()
                await fetchSitemapLabel()
            }

            guard let service = openAPIService else {
                diagnostics.log(
                    status: "failed",
                    page: currentPage,
                    rowCount: rowInputs.count,
                    errorDescription: "Sitemap service unavailable"
                )
                return
            }

            var lastResponseAt: Date?
            diagnostics.beginInitialRequest()

            for try await event in SitemapPageLoader.stream(
                sitemapName: defaultSitemap,
                pageId: pageId,
                service: service,
                shouldRetry: shouldRetryLongPolling,
                onLongPollError: { _, requestMs, willRetry in
                    Task { @MainActor in
                        SitemapDiagnostics.logLongPoll(
                            requestMs: requestMs,
                            returnedPage: false,
                            status: willRetry ? "retry" : "failed",
                            responseGapMs: nil
                        )
                    }
                }
            ) {
                try Task.checkCancellation()
                guard activePageHandlingID == runID else {
                    logger.info("Ignoring stale page result for run \(runID.uuidString, privacy: .public)")
                    return
                }

                let responseAt = Date()

                switch event {
                case let .initialFetch(page):
                    isLoading = false
                    isUpdating = false
                    diagnostics.beginUIPreparation()
                    if let page {
                        await updateUI(with: page, origin: .initialPoll)
                    }
                    diagnostics.log(
                        status: page == nil ? "empty" : "success",
                        page: page,
                        rowCount: rowInputs.count
                    )
                    logger.info("Sitemap pipeline initial load completed")
                case let .longPoll(page, requestMs):
                    let responseGapMs = lastResponseAt.map { Int((responseAt.timeIntervalSince($0) * 1000).rounded()) }
                    SitemapDiagnostics.logLongPoll(
                        requestMs: requestMs,
                        returnedPage: true,
                        status: "success",
                        responseGapMs: responseGapMs
                    )
                    scheduleLongPollUIUpdate(page: page, runID: runID)
                }

                lastResponseAt = responseAt
            }
        } catch {
            diagnostics.log(
                status: error is CancellationError ? "cancelled" : "failed",
                page: currentPage,
                rowCount: rowInputs.count,
                errorDescription: error.localizedDescription
            )
            handlePageHandlingError(error)
        }
    }

    private func ensureSitemapAvailableForHandling() async -> Bool {
        if defaultSitemap.isEmpty {
            await discoverAndSelectSitemap()
        }
        guard !defaultSitemap.isEmpty else {
            logger.error("startPageHandling: Cannot run with empty sitemap after discovery")
            isLoading = false
            isUpdating = false
            return false
        }
        return true
    }

    private func waitForConnectionForHandling() async -> ConnectionInfo? {
        if let activeConnection = networkTracker.activeConnection {
            activeConnectionInfo = activeConnection
            openHABRootUrl = activeConnection.configuration.url
            return activeConnection
        }
        activeConnectionInfo = nil

        guard let activeConnection = await NetworkTracker.shared.waitForActiveConnection() else {
            logger.error("Failed to establish connection within timeout")
            isLoading = false
            isUpdating = false
            return nil
        }
        activeConnectionInfo = activeConnection
        openHABRootUrl = activeConnection.configuration.url
        return activeConnection
    }

    private func setupServiceIfNeeded(activeConnection: ConnectionInfo, forceRecreate: Bool = false) throws {
        if forceRecreate || openAPIService == nil {
            openAPIService = try makeSitemapService(for: activeConnection)
            if forceRecreate {
                logger.info("Recreated OpenAPIService for fresh sitemap polling")
            }
        }
    }

    private func scheduleLongPollUIUpdate(page: OpenHABPage, runID: UUID) {
        let minInterval: TimeInterval = 0.25
        let elapsed = Date().timeIntervalSince(lastUIUpdateAt)

        if elapsed >= minInterval {
            // Quiet period has elapsed — apply immediately, no delay.
            longPollDebounceTask?.cancel()
            longPollDebounceTask = nil
            pendingLongPollPage = nil
            lastUIUpdateAt = Date()
            SitemapDiagnostics.logLongPollDebounce(
                action: "immediate",
                elapsedMs: Int((elapsed * 1000).rounded()),
                remainingMs: 0,
                replacedPendingPage: false,
                coalescedUpdates: coalescedLongPollUpdateCount
            )
            coalescedLongPollUpdateCount = 0
            Task { @MainActor [weak self] in
                await self?.updateUI(with: page, origin: .longPolling)
            }
        } else {
            // Within burst window — store latest page and (re)schedule a deferred apply.
            // Earlier pending page is discarded; the newest server state always wins.
            let replacedPendingPage = pendingLongPollPage != nil
            coalescedLongPollUpdateCount += 1
            pendingLongPollPage = page
            longPollDebounceTask?.cancel()
            let remaining = minInterval - elapsed
            SitemapDiagnostics.logLongPollDebounce(
                action: "scheduled",
                elapsedMs: Int((elapsed * 1000).rounded()),
                remainingMs: Int((remaining * 1000).rounded()),
                replacedPendingPage: replacedPendingPage,
                coalescedUpdates: coalescedLongPollUpdateCount
            )
            let deferredStartedAt = Date()
            longPollDebounceTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(remaining))
                guard let self, !Task.isCancelled,
                      activePageHandlingID == runID,
                      let page = pendingLongPollPage else { return }
                pendingLongPollPage = nil
                lastUIUpdateAt = Date()
                SitemapDiagnostics.logLongPollDebounce(
                    action: "deferredApply",
                    elapsedMs: Int((Date().timeIntervalSince(deferredStartedAt) * 1000).rounded()),
                    remainingMs: 0,
                    replacedPendingPage: false,
                    coalescedUpdates: coalescedLongPollUpdateCount
                )
                coalescedLongPollUpdateCount = 0
                await updateUI(with: page, origin: .longPolling)
            }
        }
    }

    @MainActor
    private func updateUI(with page: OpenHABPage, origin: PageUpdateOrigin) async {
        let updateStartedAt = Date()
        logger.debug("Incoming sitemap update origin=\(origin.rawValue, privacy: .public), widgets=\(page.widgets.count)")
        let titleChanged = currentPage == nil || currentPage?.title != page.title
        let oldInputs = rowInputs
        let newWidgets = page.widgets

        // Phase 1: apply new page directly — no reconcile needed.
        // The new architecture (SitemapRowInput value types + WidgetRenderKey change detection)
        // does not rely on widget object identity.
        let applyStartedAt = Date()
        injectSendCommand(for: newWidgets)
        currentPage = page

        // Phase 2: slider override sync
        _ = clearSyncedSliderOverrides(using: newWidgets)
        let firstApplyMs = Int((Date().timeIntervalSince(applyStartedAt) * 1000).rounded())

        // Phase 3: row input rebuild (incremental — reuses inputs for unchanged rows)
        let pageKey = "\(defaultSitemap)|\(pageId)"
        let visibleWidgets = relevantWidgets
        let prevRenderKeys = previousBuildRenderKeys
        let prevRowIDs = previousBuildRowIDs
        let prevInputs = rowInputs
        rowInputRebuildTask?.cancel()
        rowInputRebuildTask = nil
        let buildStartedAt = Date()
        let rowInputBuildResult = await SitemapPageViewModel.buildRowInputs(
            pageKey: pageKey,
            widgets: visibleWidgets,
            previousRenderKeys: prevRenderKeys,
            previousInputs: prevInputs,
            previousRowIDs: prevRowIDs
        )
        let buildRowInputsMs = Int((Date().timeIntervalSince(buildStartedAt) * 1000).rounded())
        let snapshotApplyStartedAt = Date()
        applySnapshotRowInputBuildResult(rowInputBuildResult, widgets: visibleWidgets)
        let snapshotApplyMs = Int((Date().timeIntervalSince(snapshotApplyStartedAt) * 1000).rounded())

        let inputsChanged = rowInputs != oldInputs

        // Bump widget update versions only for rows whose content changed.
        // When count is stable, zip lets us pinpoint exactly which rows differ.
        // When structure changed (rows added/removed), fall back to bumping all.
        if inputsChanged {
            if rowInputs.count == oldInputs.count {
                for (newInput, oldInput) in zip(rowInputs, oldInputs) where newInput != oldInput {
                    if let widget = rowWidgetIndex[newInput.rowID] {
                        widgetUpdateVersions[widget.widgetId, default: 0] += 1
                    }
                }
            } else {
                trackWidgetUpdates(in: newWidgets)
            }
        }

        // Diagnostic logging — all O(N) analysis work is guarded so it never runs in production.
        if SitemapDiagnostics.isEnabled {
            let t0 = Date()
            let changedRowCount = rowInputs.count == oldInputs.count
                ? zip(rowInputs, oldInputs).reduce(into: 0) { n, pair in if pair.0 != pair.1 { n += 1 } }
                : rowInputs.count
            let changedRowKinds = SitemapDiagnostics.changedRowKinds(from: oldInputs, to: rowInputs)
            let analysisMs = Int((Date().timeIntervalSince(t0) * 1000).rounded())
            SitemapDiagnostics.logUpdate(
                origin: origin,
                widgetCount: page.widgets.count,
                rowCount: rowInputs.count,
                inputsChanged: inputsChanged,
                titleChanged: titleChanged,
                reusedInputCount: rowInputBuildResult.reusedInputCount,
                changedRowCount: changedRowCount,
                changedRowKinds: changedRowKinds,
                analysisMs: analysisMs,
                buildRowInputsMs: buildRowInputsMs,
                applyStateMs: firstApplyMs + snapshotApplyMs,
                totalUpdateMs: Int((Date().timeIntervalSince(updateStartedAt) * 1000).rounded())
            )
            let iconSnapshot = await IconLoadDiagnostics.shared.snapshotAndReset()
            SitemapDiagnostics.logIconSummary(iconSnapshot)
        }
    }

    private func applySnapshotRowInputBuildResult(_ result: SnapshotRowInputBuildResult, widgets: [OpenHABWidget]) {
        var index: [RowID: OpenHABWidget] = [:]
        index.reserveCapacity(min(result.rowIDs.count, widgets.count))
        for (rowID, widget) in zip(result.rowIDs, widgets) {
            index[rowID] = widget
        }

        rowWidgetIndex = index
        previousBuildRenderKeys = result.renderKeys
        previousBuildRowIDs = result.rowIDs
        if result.inputs != rowInputs {
            rowInputs = result.inputs
        }
    }

    private func trackWidgetUpdates(in widgets: [OpenHABWidget]) {
        for widget in widgets {
            widgetUpdateVersions[widget.widgetId, default: 0] += 1
        }
    }

    private func clearSyncedSliderOverrides(using widgets: [OpenHABWidget]) -> Int {
        guard !sliderValueOverrides.isEmpty else { return 0 }
        var cleared = 0

        for widget in widgets {
            guard let item = widget.item else {
                cleared += clearSyncedSliderOverrides(using: widget.widgets)
                continue
            }

            let itemname = item.name
            guard let overrideValue = sliderValueOverrides[itemname] else {
                cleared += clearSyncedSliderOverrides(using: widget.widgets)
                continue
            }

            let serverValue = item.state?.parseAsNumber(format: item.stateDescription?.numberPattern).value ?? .nan
            guard serverValue.isFinite else {
                cleared += clearSyncedSliderOverrides(using: widget.widgets)
                continue
            }

            let threshold = max(widget.step, 0.001)
            if abs(serverValue - overrideValue) <= threshold {
                clearSliderOverride(for: itemname)
                cleared += 1
                logger.debug("Cleared slider override for \(itemname, privacy: .public) (server=\(serverValue), override=\(overrideValue))")
            }

            cleared += clearSyncedSliderOverrides(using: widget.widgets)
        }

        return cleared
    }

    func reload() async {
        do {
            isLoading = true
            try await setupConnection()
            // Fetch sitemap label if we don't have it yet
            if defaultSitemapLabel.isEmpty {
                await fetchSitemapLabel()
            }
            try await loadCurrentPage()
        } catch {
            self.error = error as? any LocalizedError
        }
        isLoading = false
    }

    private func setupConnection() async throws {
        guard let activeConnection = await NetworkTracker.shared.waitForActiveConnection() else {
            throw SitemapPageError.noActiveConnection
        }

        activeConnectionInfo = activeConnection
        openAPIService = try makeSitemapService(for: activeConnection)
    }

    private func loadCurrentPage() async throws {
        guard let service = openAPIService else { throw SitemapPageError.serviceUnavailable }

        guard let page = try await service.pollDataForPage(
            sitemapname: defaultSitemap,
            pageId: pageId,
            longPolling: false
        ) else {
            throw SitemapPageError.noData
        }

        injectSendCommand(for: page.widgets)
        currentPage = page
        let result = await SitemapPageViewModel.buildRowInputs(pageKey: "\(defaultSitemap)|\(pageId)", widgets: relevantWidgets)
        applySnapshotRowInputBuildResult(result, widgets: relevantWidgets)
    }

    private nonisolated func shouldRetryLongPolling(after error: any Error) -> Bool {
        if let urlError = OpenAPIErrorInspector.underlyingURLError(from: error) {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .cannotConnectToHost, .notConnectedToInternet, .cannotFindHost:
                return true
            default:
                break
            }
        }

        if let openAPIError = error as? OpenAPIServiceError {
            switch openAPIError {
            case let .undocumented(statusCode, _):
                return statusCode == 408 || statusCode == 499 || statusCode == 502 || statusCode == 503 || statusCode == 504
            case .badRequest, .notFound, .noRootURL, .unAuthorized:
                break
            }
        }

        return false
    }

    private func injectSendCommand(for widgets: [OpenHABWidget]) {
        for widget in widgets {
            widget.sendCommand = { [weak self] item, command in
                self?.sendCommand(item, commandToSend: command)
            }

            // If widget has nested children (e.g., frames/groups), inject recursively
            injectSendCommand(for: widget.widgets)
        }
    }

    @MainActor
    func configureSitemap(name: String, pageId: String?) {
        defaultSitemap = name
        defaultSitemapLabel = ""
        self.pageId = pageId ?? ""
        navigationPath = []
        error = nil
    }

    @MainActor
    func navigateToLinkedPage(_ nav: LinkedPageNavigation) {
        navigationPath.append(nav)
    }

    @MainActor
    // swiftlint:disable:next async_without_await
    func pushSitemap(name: String, path: String?) async {
        configureSitemap(name: name, pageId: path)
        startPageHandling(forceRestart: true, reason: "push-sitemap")
    }

    private func fetchSitemapLabel() async {
        guard let service = openAPIService else {
            logger.error("OpenAPI service not available for fetching sitemap label")
            return
        }

        do {
            let sitemaps = try await service.openHABSitemaps()

            // Find the sitemap matching our defaultSitemap name and get its label
            if let sitemap = sitemaps.first(where: { $0.name == defaultSitemap }) {
                defaultSitemapLabel = sitemap.label
                // swiftformat:disable:next redundantSelf
                logger.info("Found label '\(self.defaultSitemapLabel, privacy: .public)' for sitemap '\(self.defaultSitemap, privacy: .public)'")
            } else {
                // swiftformat:disable:next redundantSelf
                logger.warning("Could not find sitemap '\(self.defaultSitemap, privacy: .public)' in available sitemaps")
            }
        } catch {
            logger.warning("Failed to fetch sitemap label: \(error.localizedDescription, privacy: .public)")
            // Don't set error here as this is not critical - we can continue without the label
        }
    }

    private func discoverAndSelectSitemap() async {
        do {
            try await setupConnection()
            guard let service = openAPIService else {
                logger.error("Could not setup service for sitemap discovery")
                return
            }

            let sitemaps = try await service.openHABSitemaps()

            // Filter out _default sitemap if there are multiple sitemaps available
            let filteredSitemaps = sitemaps.count > 1 ? sitemaps.filter { $0.name != "_default" } : sitemaps

            switch filteredSitemaps.count {
            case 1:
                // Auto-select the only available sitemap
                defaultSitemap = filteredSitemaps[0].name
                defaultSitemapLabel = filteredSitemaps[0].label
                // swiftformat:disable:next redundantSelf
                logger.info("Auto-selected single sitemap: \(self.defaultSitemap, privacy: .public)")

                // Save as default for future launches
                Preferences.shared.modifyActiveHome { homePreferences in
                    homePreferences.defaultSitemap = defaultSitemap
                }
            case 2...:
                // Multiple sitemaps available - select the first one
                defaultSitemap = filteredSitemaps[0].name
                defaultSitemapLabel = filteredSitemaps[0].label
                // swiftformat:disable:next redundantSelf
                logger.info("Auto-selected first sitemap from \(filteredSitemaps.count, privacy: .public) available: \(self.defaultSitemap, privacy: .public)")

                // Save as default for future launches
                Preferences.shared.modifyActiveHome { homePreferences in
                    homePreferences.defaultSitemap = defaultSitemap
                }
            default:
                logger.error("No sitemaps available")
                error = SitemapPageError.serviceUnavailable
            }
        } catch {
            logger.error("Failed to discover sitemaps: \(error.localizedDescription, privacy: .public)")
            self.error = error as? any LocalizedError ?? SitemapPageError.serviceUnavailable
        }
    }

    func handleActiveConnectionChange(_ activeConnection: ConnectionInfo?) {
        guard let activeConnection else { return }

        logger.info("SitemapPageViewModel tracker connection \(activeConnection.configuration.publicLogDescription, privacy: .public)")

        // Skip if already connected to this URL — avoids restarting long-polling
        // when the NetworkTracker re-evaluates to the same connection
        let connectionDidChange = openHABRootUrl != activeConnection.configuration.url
        let hasRunningPageTask = pageHandlingTask != nil && pageHandlingTask?.isCancelled == false
        let networkStatusDidChange = pageNetworkStatusChanged()
        guard connectionDidChange || (networkStatusDidChange && !hasRunningPageTask) else {
            return
        }

        Task {
            await handleActiveConnection(activeConnection)
        }
    }

    @discardableResult
    private func pageNetworkStatusChanged() -> Bool {
        logger.info("SitemapPageViewModel pageNetworkStatusChange")

        let currentStatus = MainActorNetworkTracker.shared.status

        // First run
        if !pageNetworkStatusAvailable {
            pageNetworkStatus = currentStatus
            pageNetworkStatusAvailable = true
            return false
        }

        if pageNetworkStatus == currentStatus {
            return false
        }
        pageNetworkStatus = currentStatus
        return true
    }

    // swiftlint:disable:next async_without_await
    private func handleActiveConnection(_ connection: ConnectionInfo) async {
        let previousURL = activeConnectionInfo?.configuration.url
        let newURL = connection.configuration.url
        let connectionDidChange = previousURL != newURL

        // Save the active connection information
        activeConnectionInfo = connection
        openHABRootUrl = newURL

        do {
            // Setup the OpenAPI service based on the new connection
            openAPIService = try makeSitemapService(for: connection)
            // Restart when connection changed, or when polling is currently inactive.
            let shouldRestart = connectionDidChange
                || pageHandlingTask == nil
                || pageHandlingTask?.isCancelled == true
            if shouldRestart {
                startPageHandling(forceRestart: true, reason: connectionDidChange ? "connection-changed" : "connection-recovered")
            }
        } catch {
            self.error = error as? any LocalizedError
        }
    }

    // swiftlint:disable:next async_without_await
    func selectSitemap() async {
        startPageHandling(forceRestart: true, reason: "select-sitemap")
    }

    private func makeSitemapService(for connection: ConnectionInfo) throws -> OpenAPIService {
        // Keep sitemap polling fresh after foreground transitions or long inactivity.
        // Long-term config disables URL cache and aligns with watchOS behavior.
        try OpenAPIService(
            connectionConfiguration: connection.configuration,
            serviceConfiguration: .longTerm
        )
    }

    // MARK: - Command Sending

    func sendCommand(_ command: String?,
                     for widget: OpenHABWidget,
                     policy: WidgetCommandPolicy = .immediate,
                     phase: WidgetCommandPhase = .change,
                     key: String? = nil,
                     fallbackItem: OpenHABItem? = nil) {
        commandDispatcher.send(
            command,
            for: widget,
            policy: policy,
            phase: phase,
            key: key,
            fallbackItem: fallbackItem
        )
    }

    func cancelPendingCommand(for widget: OpenHABWidget, key: String? = nil) {
        commandDispatcher.cancelPending(for: widget, key: key)
    }

    func cancelPendingCommand(for item: OpenHABItem, key: String? = nil) {
        commandDispatcher.cancelPending(for: item, key: key)
    }

    func cancelPendingCommand(for itemname: String, key: String? = nil) {
        commandDispatcher.cancelPending(for: itemname, key: key)
        if key == nil {
            queuedCommands.removeValue(forKey: itemname)
            clearSliderOverride(for: itemname)
            if case .queued = commandStates[itemname] {
                setCommandState(.idle, for: itemname)
            }
        }
    }

    func sendCommand(_ command: String?,
                     for itemname: String,
                     policy: WidgetCommandPolicy = .immediate,
                     phase: WidgetCommandPhase = .change,
                     key: String? = nil) {
        commandDispatcher.send(
            command,
            for: itemname,
            policy: policy,
            phase: phase,
            key: key
        ) { [weak self] itemname, command in
            self?.sendCommand(itemname: itemname, command: command, origin: .command)
        }
    }

    func sendCommand(_ item: OpenHABItem?, commandToSend command: String?) {
        commandDispatcher.send(command, for: item, policy: .immediate, phase: .change) { [weak self] itemname, command in
            self?.sendCommand(itemname: itemname, command: command, origin: .command)
        }
    }

    func sendCommand(itemname: String, command: String) {
        sendCommand(itemname: itemname, command: command, origin: .command)
    }

    private func sendCommand(itemname: String, command: String, origin: CommandSendOrigin) {
        logger.debug("Dispatching command origin=\(origin.rawValue, privacy: .public), item=\(itemname, privacy: .public), command=\(command, privacy: .private(mask: .hash))")
        let version = nextCommandVersion(for: itemname)
        if trackerStatus != .connected {
            queuedCommands[itemname] = QueuedCommand(command: command, version: version)
            setCommandState(.queued, for: itemname)
            return
        }
        sendCommandNow(itemname: itemname, command: command, version: version)
    }

    private func sendCommandNow(itemname: String, command: String, version: Int) {
        setCommandState(.sending, for: itemname)
        let deviceId = UIDevice.current.identifierForVendor?.uuidString
        let sourcePrefix = pageId.isEmpty ? nil : "org.openhab.ui.basic$\(defaultSitemap):\(pageId)"
        Task { [weak self] in
            guard let self else { return }
            do {
                try await openAPIService?.sendItemCommand(
                    itemname: itemname,
                    command: command,
                    sourcePrefix: sourcePrefix,
                    deviceId: deviceId
                )
                logger.info("Successfully sent command \(command, privacy: .private(mask: .hash)) to \(itemname, privacy: .public)")
                handleCommandSuccess(for: itemname, version: version)
            } catch {
                logger.info("Failed to send command \(command, privacy: .private(mask: .hash)) to \(itemname, privacy: .public): \(error.localizedDescription, privacy: .public)")
                handleCommandFailure(for: itemname, version: version, errorDescription: error.localizedDescription)
            }
        }
    }

    private func flushQueuedCommands() {
        guard trackerStatus == .connected, !queuedCommands.isEmpty else { return }
        let queued = queuedCommands
        queuedCommands.removeAll()
        for (itemname, queuedCommand) in queued {
            guard commandStateVersions[itemname] == queuedCommand.version else { continue }
            sendCommandNow(itemname: itemname, command: queuedCommand.command, version: queuedCommand.version)
        }
    }

    func sendToUpdate(item: OpenHABItem?,
                      state: NumberState?,
                      policy: WidgetCommandPolicy = .immediate,
                      phase: WidgetCommandPhase = .change,
                      key: String? = nil) {
        guard let item, let state else {
            logger.info("ItemUpdate for Item or State = nil")
            return
        }
        let command = state.commandString
        commandDispatcher.send(command, for: item, policy: policy, phase: phase, key: key) { [weak self] itemname, command in
            self?.sendCommand(itemname: itemname, command: command, origin: .update)
        }
    }

    func sendToUpdate(itemname: String,
                      state: NumberState?,
                      policy: WidgetCommandPolicy = .immediate,
                      phase: WidgetCommandPhase = .change,
                      key: String? = nil) {
        guard !itemname.isEmpty, let state else {
            logger.info("ItemUpdate for itemname or state = nil")
            return
        }
        let command = state.commandString
        commandDispatcher.send(command, for: itemname, policy: policy, phase: phase, key: key) { [weak self] itemname, command in
            self?.sendCommand(itemname: itemname, command: command, origin: .update)
        }
    }
}

@MainActor
private extension SitemapPageViewModel {
    func nextCommandVersion(for itemname: String) -> Int {
        let newVersion = (commandStateVersions[itemname] ?? 0) + 1
        commandStateVersions[itemname] = newVersion
        return newVersion
    }

    func setCommandState(_ state: WidgetCommandLifecycleState, for itemname: String) {
        commandStateResetTasks[itemname]?.cancel()
        commandStateResetTasks[itemname] = nil

        switch state {
        case .idle:
            commandStates.removeValue(forKey: itemname)
        case .queued, .sending, .failed:
            commandStates[itemname] = state
        }
    }

    func handleCommandSuccess(for itemname: String, version: Int) {
        guard commandStateVersions[itemname] == version else { return }
        scheduleCommandStateReset(for: itemname, version: version, after: .milliseconds(450))
        scheduleSliderOverrideResetFallback(for: itemname, version: version, after: .seconds(1))
    }

    func handleCommandFailure(for itemname: String, version: Int, errorDescription: String) {
        guard commandStateVersions[itemname] == version else { return }
        clearSliderOverride(for: itemname)
        setCommandState(.failed(message: errorDescription), for: itemname)
    }

    func scheduleCommandStateReset(for itemname: String, version: Int, after delay: Duration) {
        commandStateResetTasks[itemname]?.cancel()
        commandStateResetTasks[itemname] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard let self else { return }
            guard commandStateVersions[itemname] == version else { return }
            setCommandState(.idle, for: itemname)
        }
    }

    func scheduleSliderOverrideResetFallback(for itemname: String, version: Int, after delay: Duration) {
        sliderOverrideResetTasks[itemname]?.cancel()
        sliderOverrideResetTasks[itemname] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard let self else { return }
            guard commandStateVersions[itemname] == version else { return }
            clearSliderOverride(for: itemname)
        }
    }

    func clearSliderOverride(for itemname: String) {
        guard sliderValueOverrides[itemname] != nil else { return }
        sliderOverrideResetTasks[itemname]?.cancel()
        sliderOverrideResetTasks[itemname] = nil
        objectWillChange.send()
        sliderValueOverrides.removeValue(forKey: itemname)
    }
}
