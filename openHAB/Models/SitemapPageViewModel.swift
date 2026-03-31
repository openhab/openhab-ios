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

enum SitemapPageError: LocalizedError {
    case noActiveConnection
    case serviceUnavailable
    case noData

    var errorDescription: String? {
        switch self {
        case .noActiveConnection:
            "No active connection available."
        case .serviceUnavailable:
            "Service unavailable."
        case .noData:
            "No page data received."
        }
    }
}

enum CommandLifecycleSummary: Equatable {
    case idle
    case sending(count: Int)
    case failed(count: Int)
}

enum SitemapInteractionSummary: Equatable {
    case onlineIdle
    case connecting
    case offline
    case queued(count: Int)
    case sending(count: Int)
    case failed(count: Int)
}

enum RowInteractionState: Equatable {
    case idle
    case offline
    case queued
    case sending
    case failed
}

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
    @Published var showSearchField = true
    @Published private(set) var commandStates: [String: WidgetCommandLifecycleState] = [:]
    @Published private(set) var trackerStatus: NetworkStatus = .stopped
    @Published private(set) var widgetUpdateVersions: [String: Int] = [:]
    @Published private(set) var rowInputs: [SitemapRowInput] = []

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
    private var sliderValueOverrides: [String: Double] = [:]
    private var sliderOverrideResetTasks: [String: Task<Void, Never>] = [:]
    private var lastForegroundRefreshAt: Date = .distantPast

    var relevantWidgets: [OpenHABWidget] {
        let widgets = currentPage?.widgets ?? []
        guard !searchText.isEmpty else { return widgets }
        return widgets.filter {
            $0.label.lowercased().contains(searchText.lowercased()) && $0.type != .frame
        }
    }

    var pageTitle: String {
        // Strip bracket content from title (e.g., "Living Room[2]" becomes "Living Room")
        let title = currentPage?.title.components(separatedBy: "[")[0].trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !title.isEmpty {
            return title
        } else if !fallbackTitle.isEmpty {
            return fallbackTitle
        } else if !defaultSitemapLabel.isEmpty {
            return defaultSitemapLabel
        } else {
            // Return empty — SitemapPageView shows a redacted placeholder title when loading
            return ""
        }
    }

    var isLinked: Bool {
        isLinkedPage
    }

    var commandLifecycleSummary: CommandLifecycleSummary {
        let failedCount = commandStates.values.reduce(into: 0) { result, state in
            if case .failed = state {
                result += 1
            }
        }
        if failedCount > 0 {
            return .failed(count: failedCount)
        }

        let sendingCount = commandStates.values.reduce(into: 0) { result, state in
            if case .sending = state {
                result += 1
            }
        }
        if sendingCount > 0 {
            return .sending(count: sendingCount)
        }
        return .idle
    }

    var sitemapInteractionSummary: SitemapInteractionSummary {
        if case let .failed(count) = commandLifecycleSummary {
            return .failed(count: count)
        }

        let queuedCount = commandStates.values.reduce(into: 0) { result, state in
            if case .queued = state {
                result += 1
            }
        }
        if queuedCount > 0 {
            return .queued(count: queuedCount)
        }

        switch trackerStatus {
        case .connected:
            if case let .sending(count) = commandLifecycleSummary {
                return .sending(count: count)
            }
            return .onlineIdle
        case .started, .connecting:
            return .connecting
        case .stopped:
            return .offline
        }
    }

    init() {
        loadSettings()
        startObservers()
    }

    init(pageUrl: String, title: String, pageId: String = "") {
        loadSettings()
        startObservers()
        isLinkedPage = true
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

    func rowInteractionState(for itemname: String?) -> RowInteractionState {
        guard let itemname, !itemname.isEmpty else { return .idle }

        if let lifecycleState = commandStates[itemname] {
            switch lifecycleState {
            case .queued:
                return .queued
            case .sending:
                return .sending
            case .failed:
                return .failed
            case .idle:
                break
            }
        }

        return trackerStatus == .connected ? .idle : .offline
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
    }

    func rebuildRowInputs() {
        let pageKey = "\(defaultSitemap)|\(pageId)"
        var occurrenceByWidgetID: [String: Int] = [:]
        var inputs: [SitemapRowInput] = []
        var index: [RowID: OpenHABWidget] = [:]
        inputs.reserveCapacity(relevantWidgets.count)
        index.reserveCapacity(relevantWidgets.count)

        for widget in relevantWidgets {
            let identityWidgetID = SitemapRowInputMapper.rowIdentityWidgetID(for: widget)
            occurrenceByWidgetID[identityWidgetID, default: 0] += 1
            let occurrence = occurrenceByWidgetID[identityWidgetID]!
            let rowID = RowID(pageKey: pageKey, widgetId: identityWidgetID, occurrence: occurrence)
            let input = SitemapRowInputMapper.map(widget: widget, rowID: rowID)
            inputs.append(input)
            index[rowID] = widget
        }

        rowWidgetIndex = index
        rowInputs = inputs
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
        pageHandlingTask?.cancel()
        foregroundRefreshTask?.cancel()
        commandStateResetTasks.values.forEach { $0.cancel() }
        commandStateResetTasks.removeAll()
        sliderOverrideResetTasks.values.forEach { $0.cancel() }
        sliderOverrideResetTasks.removeAll()
    }
}

@MainActor
extension SitemapPageViewModel {
    func loadSettings() {
        defaultSitemap = Preferences.shared.currentHomePreferences.defaultSitemap
        showSearchField = Preferences.shared.currentHomePreferences.showSearchField
    }

    func stopPageHandling() {
        pageHandlingTask?.cancel()
        pageHandlingTask = nil
        foregroundRefreshTask?.cancel()
        foregroundRefreshTask = nil
        activePageHandlingKey = nil
        activePageHandlingID = nil
    }

    func refreshOnForeground() {
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
        let pipelineStart = Date()
        let requestedKey = "\(defaultSitemap)|\(pageId)"
        if !forceRestart,
           let activeTask = pageHandlingTask,
           !activeTask.isCancelled,
           activePageHandlingKey == requestedKey {
            logger.info("Skipping duplicate page handling start for \(requestedKey, privacy: .public), reason: \(reason, privacy: .public)")
            return
        }

        pageHandlingTask?.cancel()
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
                recreateService: recreateService,
                pipelineStart: pipelineStart
            )
        }
    }

    private func runPageHandling(
        runID: UUID,
        recreateService: Bool,
        pipelineStart: Date
    ) async {
        defer {
            if activePageHandlingID == runID {
                pageHandlingTask = nil
                activePageHandlingID = nil
            }
        }

        do {
            guard await ensureSitemapAvailableForHandling() else { return }

            guard let activeConnection = await waitForConnectionForHandling() else { return }

            try setupServiceIfNeeded(activeConnection: activeConnection, forceRecreate: recreateService)

            if defaultSitemapLabel.isEmpty {
                await fetchSitemapLabel()
            }

            try await loadInitialPageForHandling(runID: runID)
            isLoading = false
            isUpdating = false
            let totalDurationMs = Date().timeIntervalSince(pipelineStart) * 1000
            logger.info("Sitemap pipeline ready in \(Int(totalDurationMs.rounded()), privacy: .public)ms")
            try await runLongPollingLoop(runID: runID)
        } catch {
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

    private func loadInitialPageForHandling(runID: UUID) async throws {
        let initialPage = try await openAPIService?.pollDataForPage(
            sitemapname: defaultSitemap,
            pageId: pageId,
            longPolling: false
        )

        try Task.checkCancellation()
        guard activePageHandlingID == runID else {
            logger.info("Ignoring stale initial page result for run \(runID.uuidString, privacy: .public)")
            return
        }

        if let page = initialPage {
            updateUI(with: page, origin: .initialPoll)
        } else {
            logger.info("Initial sitemap poll returned no page data")
        }
    }

    private func runLongPollingLoop(runID: UUID) async throws {
        while !Task.isCancelled {
            do {
                let page = try await openAPIService?.pollDataForPage(
                    sitemapname: defaultSitemap,
                    pageId: pageId,
                    longPolling: true
                )
                try Task.checkCancellation()
                guard activePageHandlingID == runID else {
                    logger.info("Ignoring stale long-poll result for run \(runID.uuidString, privacy: .public)")
                    return
                }

                if let page {
                    updateUI(with: page, origin: .longPolling)
                }
            } catch {
                try Task.checkCancellation()
                guard shouldRetryLongPolling(after: error) else {
                    throw error
                }

                logger.info("Transient long-polling error, retrying: \(error.localizedDescription, privacy: .public)")
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    @MainActor
    private func updateUI(with page: OpenHABPage, origin: PageUpdateOrigin) {
        logger.debug("Incoming sitemap update origin=\(origin.rawValue, privacy: .public), widgets=\(page.widgets.count)")
        let newWidgets = page.widgets

        // Check if list structure changed (count, order, or IDs)
        let currentWidgets = currentPage?.widgets ?? []
        let structureChanged = currentWidgets.count != newWidgets.count
            || !zip(currentWidgets, newWidgets).allSatisfy { $0.widgetId == $1.widgetId }
        let reconciledWidgets = reconcileWidgets(newWidgets, with: currentWidgets)

        // Only replace currentPage when structure or title changed
        if structureChanged || currentPage?.title != page.title || currentPage == nil {
            page.widgets = reconciledWidgets
            injectSendCommand(for: reconciledWidgets)
            currentPage = page
        } else {
            currentPage?.widgets = reconciledWidgets
            // Inject sendCommand into existing widgets without replacing the page
            injectSendCommand(for: reconciledWidgets)
        }

        trackWidgetUpdates(in: reconciledWidgets)
        _ = clearSyncedSliderOverrides(using: reconciledWidgets)
        rebuildRowInputs()
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
        rebuildRowInputs()
    }

    private func reconcileWidgets(_ newWidgets: [OpenHABWidget], with currentWidgets: [OpenHABWidget]) -> [OpenHABWidget] {
        var buckets: [String: [OpenHABWidget]] = [:]
        for widget in currentWidgets {
            buckets[widget.widgetId, default: []].append(widget)
        }

        var reconciled: [OpenHABWidget] = []
        reconciled.reserveCapacity(newWidgets.count)

        for newWidget in newWidgets {
            if var candidates = buckets[newWidget.widgetId], !candidates.isEmpty {
                let existing = candidates.removeFirst()
                buckets[newWidget.widgetId] = candidates

                // Always copy server properties to avoid missing updates when
                // non-keyed fields change (for example group summary/state rows).
                let previousChildren = existing.widgets
                copyWidgetProperties(from: newWidget, to: existing)
                existing.widgets = reconcileWidgets(newWidget.widgets, with: previousChildren)

                reconciled.append(existing)
            } else {
                reconciled.append(newWidget)
            }
        }

        return reconciled
    }

    private func copyWidgetProperties(from source: OpenHABWidget, to target: OpenHABWidget) {
        target.label = source.label
        target.icon = source.icon
        target.state = source.state
        target.type = source.type
        target.isLeaf = source.isLeaf
        target.item = source.item
        target.iconColor = source.iconColor
        target.labelcolor = source.labelcolor
        target.valuecolor = source.valuecolor
        target.url = source.url
        target.period = source.period
        target.service = source.service
        target.legend = source.legend
        target.refresh = source.refresh
        target.height = source.height
        target.forceAsItem = source.forceAsItem
        target.minValue = source.minValue
        target.maxValue = source.maxValue
        target.step = source.step
        target.pattern = source.pattern
        target.unit = source.unit
        target.switchSupport = source.switchSupport
        target.mappings = source.mappings
        target.linkedPage = source.linkedPage
        target.visibility = source.visibility
        target.staticIcon = source.staticIcon
        target.text = source.text
        target.inputHint = source.inputHint
        target.encoding = source.encoding
        target.labelSource = source.labelSource
        target.releaseOnly = source.releaseOnly
        target.row = source.row
        target.column = source.column
        target.releaseCommand = source.releaseCommand
        target.command = source.command
        target.stateless = source.stateless
        target.yAxisDecimalPattern = source.yAxisDecimalPattern
    }

    private func shouldRetryLongPolling(after error: any Error) -> Bool {
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
    func pushSitemap(name: String, path: String?) async {
        defaultSitemap = name
        defaultSitemapLabel = "" // Clear old label so it gets fetched for the new sitemap
        pageId = path ?? ""
        error = nil // Clear any previous errors when switching sitemaps
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
                logger.info("Found label '\(self.defaultSitemapLabel)' for sitemap '\(self.defaultSitemap)'")
            } else {
                // swiftformat:disable:next redundantSelf
                logger.warning("Could not find sitemap '\(self.defaultSitemap)' in available sitemaps")
            }
        } catch {
            logger.warning("Failed to fetch sitemap label: \(error)")
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
                logger.info("Auto-selected single sitemap: \(self.defaultSitemap)")

                // Save as default for future launches
                Preferences.shared.modifyActiveHome { homePreferences in
                    homePreferences.defaultSitemap = defaultSitemap
                }
            case 2...:
                // Multiple sitemaps available - select the first one
                defaultSitemap = filteredSitemaps[0].name
                defaultSitemapLabel = filteredSitemaps[0].label
                // swiftformat:disable:next redundantSelf
                logger.info("Auto-selected first sitemap from \(filteredSitemaps.count) available: \(self.defaultSitemap)")

                // Save as default for future launches
                Preferences.shared.modifyActiveHome { homePreferences in
                    homePreferences.defaultSitemap = defaultSitemap
                }
            default:
                logger.error("No sitemaps available")
                error = SitemapPageError.serviceUnavailable
            }
        } catch {
            logger.error("Failed to discover sitemaps: \(error)")
            self.error = error as? any LocalizedError ?? SitemapPageError.serviceUnavailable
        }
    }

    func handleActiveConnectionChange(_ activeConnection: ConnectionInfo?) {
        guard let activeConnection else { return }

        logger.info("SitemapPageViewModel tracker URL \(activeConnection.configuration.url)")

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
        } else {
            pageNetworkStatus = currentStatus
            return true
        }
    }

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
        Task { [weak self] in
            guard let self else { return }
            do {
                try await openAPIService?.sendItemCommand(
                    itemname: itemname,
                    command: command,
                    sourcePrefix: nil,
                    deviceId: deviceId
                )
                logger.info("Successfully sent command \(command) to \(itemname)")
                handleCommandSuccess(for: itemname, version: version)
            } catch {
                logger.info("Failed to send command\(command) to \(itemname): \(error.localizedDescription)")
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
    func handlePageHandlingError(_ error: any Error) {
        if error is CancellationError {
            logger.info("🔁 pageHandlingTask was cancelled")
            isLoading = false
            isUpdating = false
            return
        }

        if let decodingError = error as? DecodingError {
            guard !Task.isCancelled else {
                logger.info("Task cancelled, ignoring DecodingError")
                isLoading = false
                isUpdating = false
                return
            }
            logger.error("Decoding error: \(decodingError.localizedDescription)")
            self.error = SitemapPageError.serviceUnavailable
            isLoading = false
            isUpdating = false
            return
        }

        if let urlError = OpenAPIErrorInspector.underlyingURLError(from: error) {
            if urlError.code == .cancelled {
                logger.info("Task cancelled (URLError: cancelled)")
            } else if urlError.code == .timedOut {
                logger.info("Task timed out (URLError: timedOut)")
            } else if !Task.isCancelled {
                logger.error("ClientError: \(urlError.localizedDescription)")
                self.error = SitemapPageError.serviceUnavailable
            } else {
                logger.info("Task cancelled, ignoring ClientError")
            }
            isLoading = false
            isUpdating = false
            return
        }

        if let clientErrorDescription = OpenAPIErrorInspector.clientErrorDescription(from: error) {
            guard !Task.isCancelled else {
                logger.info("Task cancelled, ignoring ClientError")
                isLoading = false
                isUpdating = false
                return
            }
            logger.error("ClientError: \(clientErrorDescription)")
            self.error = SitemapPageError.serviceUnavailable
            isLoading = false
            isUpdating = false
            return
        }

        if let openAPIError = error as? OpenAPIServiceError {
            logger.error("OpenAPIServiceError: \(openAPIError.localizedDescription)")
            isLoading = false
            isUpdating = false
            return
        }

        guard !Task.isCancelled else {
            logger.info("Task cancelled, ignoring error")
            isLoading = false
            isUpdating = false
            return
        }
        logger.error("❌ Unhandled pageHandlingTask error: \(error.localizedDescription)")
        self.error = SitemapPageError.serviceUnavailable
        isLoading = false
        isUpdating = false
    }

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
        scheduleSliderOverrideResetFallback(for: itemname, version: version, after: .seconds(5))
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

extension Published.Publisher where Output: Sendable {
    func stream() -> AsyncStream<Output> {
        AsyncStream { continuation in
            let cancellable = self.sink { value in
                continuation.yield(value)
            }
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }
}
