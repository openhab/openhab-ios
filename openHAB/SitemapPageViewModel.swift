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
import OpenAPIRuntime
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

private struct WidgetRenderKey: Equatable {
    let label: String
    let icon: String
    let state: String
    let iconColor: String
    let labelColor: String
    let valueColor: String
    let url: String
    let period: String
    let service: String
    let legend: Bool?
    let refresh: Int
    let height: Double?
    let forceAsItem: Bool?
    let visibility: Bool
    let staticIcon: Bool?
    let switchSupport: Bool
    let minValue: Double
    let maxValue: Double
    let step: Double
    let pattern: String?
    let unit: String?
    let type: OpenHABWidget.WidgetType
    let linkedPageLink: String?
    let linkedPageTitle: String?
    let mappings: [WidgetMappingKey]
    let item: WidgetItemKey?
    let childWidgetIDs: [String]

    static func from(widget: OpenHABWidget) -> WidgetRenderKey {
        WidgetRenderKey(
            label: widget.label,
            icon: widget.icon,
            state: widget.state,
            iconColor: widget.iconColor,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            url: widget.url,
            period: widget.period,
            service: widget.service,
            legend: widget.legend,
            refresh: widget.refresh,
            height: widget.height,
            forceAsItem: widget.forceAsItem,
            visibility: widget.visibility,
            staticIcon: widget.staticIcon,
            switchSupport: widget.switchSupport,
            minValue: widget.minValue,
            maxValue: widget.maxValue,
            step: widget.step,
            pattern: widget.pattern,
            unit: widget.unit,
            type: widget.type,
            linkedPageLink: widget.linkedPage?.link,
            linkedPageTitle: widget.linkedPage?.title,
            mappings: widget.mappings.map(WidgetMappingKey.init),
            item: WidgetItemKey.from(item: widget.item),
            childWidgetIDs: widget.widgets.map(\.widgetId)
        )
    }
}

private struct WidgetMappingKey: Equatable {
    let command: String
    let label: String
    let row: Int?
    let column: Int?
    let icon: String?
    let releaseCommand: String?

    init(_ mapping: OpenHABWidgetMapping) {
        command = mapping.command
        label = mapping.label
        row = mapping.row
        column = mapping.column
        icon = mapping.icon
        releaseCommand = mapping.releaseCommand
    }
}

private struct WidgetItemKey: Equatable {
    let name: String
    let state: String?
    let link: String
    let label: String
    let type: OpenHABItem.ItemType?
    let groupType: OpenHABItem.ItemType?
    let stateDescription: WidgetStateDescriptionKey?
    let commandOptions: [WidgetCommandOptionKey]

    static func from(item: OpenHABItem?) -> WidgetItemKey? {
        guard let item else { return nil }
        return WidgetItemKey(
            name: item.name,
            state: item.state,
            link: item.link,
            label: item.label,
            type: item.type,
            groupType: item.groupType,
            stateDescription: WidgetStateDescriptionKey.from(stateDescription: item.stateDescription),
            commandOptions: item.commandDescription?.commandOptions.map(WidgetCommandOptionKey.init) ?? []
        )
    }
}

private struct WidgetStateDescriptionKey: Equatable {
    let minimum: Double
    let maximum: Double
    let step: Double
    let readOnly: Bool
    let numberPattern: String?
    let options: [WidgetOptionKey]

    static func from(stateDescription: OpenHABStateDescription?) -> WidgetStateDescriptionKey? {
        guard let stateDescription else { return nil }
        return WidgetStateDescriptionKey(
            minimum: stateDescription.minimum,
            maximum: stateDescription.maximum,
            step: stateDescription.step,
            readOnly: stateDescription.readOnly,
            numberPattern: stateDescription.numberPattern,
            options: stateDescription.options.map(WidgetOptionKey.init)
        )
    }
}

private struct WidgetOptionKey: Equatable {
    let value: String
    let label: String

    init(_ option: OpenHABOptions) {
        value = option.value
        label = option.label
    }
}

private struct WidgetCommandOptionKey: Equatable {
    let command: String
    let label: String?

    init(_ option: OpenHABCommandOptions) {
        command = option.command
        label = option.label
    }
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
    @Published var showSearchField = false
    @Published private(set) var commandStates: [String: WidgetCommandLifecycleState] = [:]
    @Published private(set) var widgetUpdateVersions: [String: Int] = [:]
    @Published private(set) var rowInputs: [SitemapRowInput] = []

    let networkTracker = MainActorNetworkTracker.shared
    private var openAPIService: OpenAPIService?
    private var activeConnectionInfo: ConnectionInfo?
    private var pageHandlingTask: Task<Void, Never>?
    private var connectionObserverTask: Task<Void, Never>?
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
    private var rowWidgetIndex: [RowID: OpenHABWidget] = [:]

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

    init() {
        loadSettings()
        // Observe connection changes (skip initial value) — initial load is triggered by .task in the view
        connectionObserverTask = Task { [weak self] in
            guard let tracker = self?.networkTracker else { return }
            for await connection in tracker.$activeConnection.values.dropFirst() {
                await MainActor.run { [weak self] in
                    self?.handleActiveConnectionChange(connection)
                }
            }
        }
    }

    init(pageUrl: String, title: String, pageId: String = "") {
        loadSettings()
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

    func rebuildRowInputs() {
        let pageKey = "\(defaultSitemap)|\(pageId)"
        var occurrenceByWidgetID: [String: Int] = [:]
        var inputs: [SitemapRowInput] = []
        var index: [RowID: OpenHABWidget] = [:]
        inputs.reserveCapacity(relevantWidgets.count)
        index.reserveCapacity(relevantWidgets.count)

        for widget in relevantWidgets {
            occurrenceByWidgetID[widget.widgetId, default: 0] += 1
            let occurrence = occurrenceByWidgetID[widget.widgetId]!
            let rowID = RowID(pageKey: pageKey, widgetId: widget.widgetId, occurrence: occurrence)
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

    deinit {
        connectionObserverTask?.cancel()
        pageHandlingTask?.cancel()
        commandStateResetTasks.values.forEach { $0.cancel() }
        commandStateResetTasks.removeAll()
    }
}

@MainActor
extension SitemapPageViewModel {
    func loadSettings() {
        defaultSitemap = Preferences.shared.currentHomePreferences.defaultSitemap
        showSearchField = Preferences.shared.applicationPreferences.showSearchField
    }

    func stopPageHandling() {
        pageHandlingTask?.cancel()
        pageHandlingTask = nil
        activePageHandlingKey = nil
        activePageHandlingID = nil
    }

    func startPageHandling(forceRestart: Bool = false, reason: String = "manual") {
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
        isLoading = true // Show redacted view immediately

        let runID = UUID()
        activePageHandlingID = runID
        activePageHandlingKey = requestedKey

        logger.info("🚀 Starting page load and long polling flow (reason: \(reason, privacy: .public), run: \(runID.uuidString, privacy: .public), key: \(requestedKey, privacy: .public))")

        pageHandlingTask = Task {
            defer {
                if activePageHandlingID == runID {
                    pageHandlingTask = nil
                    activePageHandlingID = nil
                }
            }

            do {
                guard await ensureSitemapAvailableForHandling() else { return }
                guard let activeConnection = await waitForConnectionForHandling() else { return }

                try setupServiceIfNeeded(activeConnection: activeConnection)

                if defaultSitemapLabel.isEmpty {
                    await fetchSitemapLabel()
                }

                try await loadInitialPageForHandling(runID: runID)
                isLoading = false
                try await runLongPollingLoop(runID: runID)
            } catch {
                handlePageHandlingError(error)
            }
        }
    }

    private func ensureSitemapAvailableForHandling() async -> Bool {
        if defaultSitemap.isEmpty {
            await discoverAndSelectSitemap()
        }
        guard !defaultSitemap.isEmpty else {
            logger.error("startPageHandling: Cannot run with empty sitemap after discovery")
            isLoading = false
            return false
        }
        return true
    }

    private func waitForConnectionForHandling() async -> ConnectionInfo? {
        guard let activeConnection = await NetworkTracker.shared.waitForActiveConnection() else {
            logger.error("Failed to establish connection within timeout")
            isLoading = false
            return nil
        }
        activeConnectionInfo = activeConnection
        openHABRootUrl = activeConnection.configuration.url
        return activeConnection
    }

    private func setupServiceIfNeeded(activeConnection: ConnectionInfo) throws {
        if openAPIService == nil {
            openAPIService = try OpenAPIService(connectionConfiguration: activeConnection.configuration)
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
            updateUI(with: page)
        }
    }

    private func runLongPollingLoop(runID: UUID) async throws {
        while !Task.isCancelled {
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
                updateUI(with: page)
            }
        }
    }

    @MainActor
    private func updateUI(with page: OpenHABPage) {
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
        rebuildRowInputs()
    }

    private func trackWidgetUpdates(in widgets: [OpenHABWidget]) {
        for widget in widgets {
            widgetUpdateVersions[widget.widgetId, default: 0] += 1
        }
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
        openAPIService = try OpenAPIService(connectionConfiguration: activeConnection.configuration)
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
                if hasRelevantWidgetDiff(from: existing, to: newWidget) {
                    copyWidgetProperties(from: newWidget, to: existing)
                } else if !newWidget.widgets.isEmpty {
                    // Parent key is unchanged, but nested children can still receive state updates.
                    existing.widgets = reconcileWidgets(newWidget.widgets, with: existing.widgets)
                }
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
        target.widgets = source.widgets
        target.linkedPage = source.linkedPage
        target.visibility = source.visibility
        target.staticIcon = source.staticIcon
    }

    private func hasRelevantWidgetDiff(from current: OpenHABWidget, to incoming: OpenHABWidget) -> Bool {
        WidgetRenderKey.from(widget: current) != WidgetRenderKey.from(widget: incoming)
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
            openAPIService = try OpenAPIService(connectionConfiguration: connection.configuration)
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
            self?.sendCommand(itemname: itemname, command: command)
        }
    }

    func sendCommand(_ item: OpenHABItem?, commandToSend command: String?) {
        commandDispatcher.send(command, for: item, policy: .immediate, phase: .change) { [weak self] itemname, command in
            self?.sendCommand(itemname: itemname, command: command)
        }
    }

    func sendCommand(itemname: String, command: String) {
        let version = nextCommandVersion(for: itemname)
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
            self?.sendCommand(itemname: itemname, command: command)
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

        if let clientError = error as? ClientError {
            if let urlError = clientError.underlyingError as? URLError, urlError.code == .cancelled {
                logger.info("Task cancelled (URLError: cancelled)")
            } else if let urlError = clientError.underlyingError as? URLError, urlError.code == .timedOut {
                logger.info("Task timed out (URLError: timedOut)")
            } else {
                guard !Task.isCancelled else {
                    logger.info("Task cancelled, ignoring ClientError")
                    isLoading = false
                    isUpdating = false
                    return
                }
                logger.error("ClientError: \(clientError.localizedDescription)")
                self.error = SitemapPageError.serviceUnavailable
            }
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
        case .sending, .failed:
            commandStates[itemname] = state
        }
    }

    func handleCommandSuccess(for itemname: String, version: Int) {
        guard commandStateVersions[itemname] == version else { return }
        scheduleCommandStateReset(for: itemname, version: version, after: .milliseconds(450))
    }

    func handleCommandFailure(for itemname: String, version: Int, errorDescription: String) {
        guard commandStateVersions[itemname] == version else { return }
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
