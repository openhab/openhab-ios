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

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "org.openhab.app", category: "SitemapPageViewModel")

enum SitemapPageError: LocalizedError {
    case noActiveConnection
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        case .noActiveConnection:
            "No active connection available."
        case .serviceUnavailable:
            "Service unavailable."
        }
    }
}

@MainActor
class SitemapPageViewModel: ObservableObject {
    @Published var currentPage: OpenHABPage?
    @Published var searchText = ""
    @Published var error: (any LocalizedError)?
    @Published var isLoading = false
    @Published var isUpdating = false
    @Published var openHABRootUrl: String?
    @Published var showSearchField = false

    let networkTracker = MainActorNetworkTracker.shared
    private var openAPIService: OpenAPIService?
    private var activeConnectionInfo: ConnectionInfo?
    private var serverProperties: OpenHABServerProperties?
    private var pageHandlingTask: Task<Void, Never>?
    private var sseStreamTask: Task<Void, Never>?
    private var sseConnected = false
    private var ssePreferred = true
    private var defaultSitemap = ""
    private var defaultSitemapLabel = ""
    @Published var pageId = ""
    private var isLinkedPage = false
    private var initialTitle = ""
    private var pageNetworkStatus: NetworkStatus?
    private var pageNetworkStatusAvailable = false

    var relevantWidgets: [OpenHABWidget] {
        let widgets = currentPage?.widgets ?? []
        guard !searchText.isEmpty else { return widgets }
        return widgets.filter {
            $0.label.lowercased().contains(searchText.lowercased()) && $0.type != .frame
        }
    }

    var pageTitle: String {
        // Strip bracket content from title (e.g., "Living Room[2]" becomes "Living Room")
        let title = currentPage?.title.components(separatedBy: "[")[0] ?? ""
        if !title.isEmpty {
            return title
        } else if !initialTitle.isEmpty {
            return initialTitle
        } else if !defaultSitemapLabel.isEmpty {
            return defaultSitemapLabel
        } else {
            // Return empty - SitemapPageView shows redacted placeholder title when loading
            return ""
        }
    }

    var isLinked: Bool {
        isLinkedPage
    }

    init() {
        loadSettings()
        setupActiveConnectionObserver()

        // Observe network connection changes directly
        Task { @MainActor in
            for await connection in networkTracker.$activeConnection.values {
                handleActiveConnectionChange(connection)
            }
        }
    }

    init(pageUrl: String, title: String, pageId: String = "") {
        loadSettings()
        setupActiveConnectionObserver()
        isLinkedPage = true
        initialTitle = title

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
        self.pageId = pageId
        currentPage = OpenHABPage(
            pageId: pageId.isEmpty ? UUID().uuidString : pageId,
            title: title,
            link: pageUrl,
            leaf: false,
            widgets: widgets,
            icon: ""
        )
    }

    func loadSettings() {
        defaultSitemap = Preferences.shared.currentHomePreferences.defaultSitemap
        showSearchField = Preferences.shared.applicationPreferences.showSearchField
    }

    func startPageHandling() {
        pageHandlingTask?.cancel()
        sseStreamTask?.cancel()
        error = nil // Clear any previous errors when starting a new page handling session
        isLoading = true // Show redacted view immediately

        logger.info("🚀 Starting page load and long polling flow...")
        // swiftformat:disable:next redundantSelf
        logger.info("Sitemap target defaultSitemap=\(self.defaultSitemap) pageId=\(self.pageId)")

        pageHandlingTask = Task {
            // If no default sitemap is set, try to discover and auto-select one
            if defaultSitemap.isEmpty {
                await discoverAndSelectSitemap()
            }

            guard !defaultSitemap.isEmpty else {
                logger.error("startPageHandling: Cannot run with empty sitemap after discovery")
                isLoading = false
                return
            }
            do {
                guard let activeConnection = await NetworkTracker.shared.waitForActiveConnection() else {
                    logger.error("Failed to establish connection within timeout")
                    isLoading = false
                    return
                }
                let configuration = activeConnection.configuration

                if openAPIService == nil {
                    openAPIService = try OpenAPIService(connectionConfiguration: configuration)
                }
                if serverProperties == nil {
                    serverProperties = try? await openAPIService?.getRoot()
                }
                logger.info("Server properties: version=\(self.serverProperties?.version ?? "nil") sse=\(self.serverProperties?.hasSseSupport() == true)")

                // Fetch sitemap label if we loaded from preferences (not from discovery)
                if defaultSitemapLabel.isEmpty {
                    await fetchSitemapLabel()
                }

                // 1. Initial page load (longPolling: false)
                let initialPage = try await openAPIService?.pollDataForPage(
                    sitemapname: defaultSitemap,
                    pageId: effectivePageId(),
                    longPolling: false
                )

                try Task.checkCancellation()

                if let page = initialPage {
                    updateUI(with: page)
                }
                isLoading = false

                if shouldUseSSE() {
                    logger.info("Using SSE for sitemap updates")
                    await startSSE(sitemap: defaultSitemap, pageId: effectivePageId())
                    return
                }
                logger.info("Using long polling fallback for sitemap updates")

                // 2. Start long polling loop (fallback)
                await startLongPollingLoop()

            } catch is CancellationError {
                logger.info("🔁 pageHandlingTask was cancelled")
                isLoading = false
                isUpdating = false
            } catch let error as DecodingError {
                // Don't set error if task was cancelled
                guard !Task.isCancelled else {
                    logger.info("Task cancelled, ignoring DecodingError")
                    isLoading = false
                    isUpdating = false
                    return
                }
                logger.error("Decoding error: \(error.localizedDescription)")
                self.error = SitemapPageError.serviceUnavailable
                isLoading = false
                isUpdating = false
            } catch let error as ClientError {
                if let urlError = error.underlyingError as? URLError, urlError.code == .cancelled {
                    logger.info("Task cancelled (URLError: cancelled)")
                } else if let urlError = error.underlyingError as? URLError, urlError.code == .timedOut {
                    logger.info("Task timed out (URLError: timedOut)")
                } else {
                    // Don't set error if task was cancelled
                    guard !Task.isCancelled else {
                        logger.info("Task cancelled, ignoring ClientError")
                        isLoading = false
                        isUpdating = false
                        return
                    }
                    logger.error("ClientError: \(error.localizedDescription)")
                    self.error = SitemapPageError.serviceUnavailable
                }
                isLoading = false
                isUpdating = false
            } catch let openAPIError as OpenAPIServiceError {
                logger.error("OpenAPIServiceError: \(openAPIError.localizedDescription)")
                isLoading = false
                isUpdating = false
            } catch {
                // Don't set error if task was cancelled
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
        }
    }

    @MainActor
    private func updateUI(with page: OpenHABPage) {
        injectSendCommand(for: page.widgets)
        currentPage = page
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
        if serverProperties == nil {
            serverProperties = try? await openAPIService?.getRoot()
        }
    }

    private func loadCurrentPage() async throws {
        guard let service = openAPIService else { throw SitemapPageError.serviceUnavailable }

        let page = try await service.pollDataForPage(
            sitemapname: defaultSitemap,
            pageId: effectivePageId(),
            longPolling: false
        )

        injectSendCommand(for: page!.widgets)
        currentPage = page
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
        startPageHandling()
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

    private func setupActiveConnectionObserver() {
        // The @ObservedObject will automatically trigger view updates
        // We'll handle the connection changes in the view's onChange modifier
    }

    func handleActiveConnectionChange(_ activeConnection: ConnectionInfo?) {
        guard let activeConnection else { return }

        logger.info("SitemapPageViewModel tracker URL \(activeConnection.configuration.url)")

        // Check if network status changed
        if pageNetworkStatusChanged() {
            logger.info("Network status changed, restarting page handling")
            pageHandlingTask?.cancel()
            // Restart page handling to establish long-polling
            startPageHandling()
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
        // Save the active connection information
        activeConnectionInfo = connection
        openHABRootUrl = connection.configuration.url
        ssePreferred = true

        do {
            // Setup the OpenAPI service based on the new connection
            openAPIService = try OpenAPIService(connectionConfiguration: connection.configuration)
            serverProperties = try? await openAPIService?.getRoot()
            // Start page handling which includes initial load and long polling
            startPageHandling()
        } catch {
            self.error = error as? any LocalizedError
        }
    }

    func selectSitemap() async {
        startPageHandling()
    }

    // MARK: - Command Sending

    func sendCommand(_ item: OpenHABItem?, commandToSend command: String?) {
        if let item, let command {
            sendCommand(itemname: item.name, command: command)
        }
    }

    func sendCommand(itemname: String, command: String) {
        Task {
            do {
                try await openAPIService?.sendItemCommand(itemname: itemname, command: command)
                logger.info("Successfully sent command \(command) to \(itemname)")
            } catch {
                logger.info("Failed to send command\(command) to \(itemname): \(error.localizedDescription)")
            }
        }
    }

    func sendToUpdate(item: OpenHABItem?, state: NumberState?) {
        guard let item, let state else {
            logger.info("ItemUpdate for Item or State = nil")
            return
        }
        if item.isOfTypeOrGroupType(.numberWithDimension) {
            // For number items, include unit (if present) in command
            sendCommand(item, commandToSend: state.toString(locale: Locale(identifier: "US")))
        } else {
            // For all other items, send the plain value
            sendCommand(item, commandToSend: state.stringValue)
        }
    }

    deinit {
        pageHandlingTask?.cancel()
        sseStreamTask?.cancel()
    }
}

private extension SitemapPageViewModel {
    func effectivePageId() -> String {
        pageId.isEmpty ? defaultSitemap : pageId
    }

    func shouldUseSSE() -> Bool {
        guard ssePreferred else { return false }
        if let serverProperties {
            return serverProperties.hasSseSupport()
        }
        if let version = activeConnectionInfo?.version {
            return version >= 3
        }
        return false
    }

    func startSSE(sitemap: String, pageId: String) async {
        sseConnected = false
        sseStreamTask?.cancel()

        logger.info("Starting sitemap SSE for \(sitemap)/\(pageId)")
        SitemapEventStream.startMonitoringNetwork()
        await SitemapEventStream.shared.setTarget(sitemap: sitemap, pageId: pageId)

        sseStreamTask = Task { [weak self] in
            guard let self else { return }
            for await msg in await SitemapEventStream.shared.stream() {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    switch msg {
                    case .connected:
                        logger.info("Sitemap SSE connected")
                        sseConnected = true
                    case let .disconnected(error):
                        logger.warning("Sitemap SSE disconnected: \(error?.localizedDescription ?? "nil")")
                        isUpdating = false
                        if let error = error as? SitemapSseError, error == .unsupported {
                            ssePreferred = false
                            startLongPollingFallback(error)
                        } else if !sseConnected {
                            ssePreferred = false
                            startLongPollingFallback(error)
                        }
                    case let .event(message):
                        handleSseMessage(message)
                    }
                }
            }
        }
    }

    func startLongPollingFallback(_ error: (any Error)?) {
        sseStreamTask?.cancel()
        sseStreamTask = nil
        Task {
            await SitemapEventStream.shared.stop()
        }
        pageHandlingTask?.cancel()
        pageHandlingTask = Task {
            if let error {
                logger.warning("SSE unavailable (\(error.localizedDescription)), falling back to long polling")
            } else {
                logger.warning("SSE unavailable, falling back to long polling")
            }
            await startLongPollingLoop()
        }
    }

    func startLongPollingLoop() async {
        while !Task.isCancelled {
            do {
                isUpdating = true
                let page = try await openAPIService?.pollDataForPage(
                    sitemapname: defaultSitemap,
                    pageId: effectivePageId(),
                    longPolling: true
                )
                isUpdating = false
                try Task.checkCancellation()

                if let page {
                    updateUI(with: page)
                }
            } catch is CancellationError {
                return
            } catch let error as DecodingError {
                logger.error("Decoding error: \(error.localizedDescription)")
                self.error = SitemapPageError.serviceUnavailable
                isUpdating = false
                return
            } catch let error as ClientError {
                if let urlError = error.underlyingError as? URLError, urlError.code == .cancelled {
                    logger.info("Task cancelled (URLError: cancelled)")
                } else if let urlError = error.underlyingError as? URLError, urlError.code == .timedOut {
                    logger.info("Task timed out (URLError: timedOut)")
                } else {
                    logger.error("ClientError: \(error.localizedDescription)")
                    self.error = SitemapPageError.serviceUnavailable
                }
                isUpdating = false
                return
            } catch let openAPIError as OpenAPIServiceError {
                logger.error("OpenAPIServiceError: \(openAPIError.localizedDescription)")
                isUpdating = false
                return
            } catch {
                logger.error("❌ Unhandled polling error: \(error.localizedDescription)")
                self.error = SitemapPageError.serviceUnavailable
                isUpdating = false
                return
            }
        }
    }
}

private extension SitemapPageViewModel {
    func handleSseMessage(_ message: SitemapEventMessage) {
        switch message {
        case .alive:
            return
        case let .sitemapChanged(sitemap, pageId):
            logger.info("SSE sitemap changed \(sitemap.orEmpty)/\(pageId.orEmpty) – reloading")
            Task {
                await SitemapEventStream.shared.stop()
            }
            startPageHandling()
        case let .widget(event):
            logger.debug("SSE widget event \(event.widgetId.orEmpty) label=\(event.label.orEmpty) visibility=\(String(describing: event.visibility))")
            guard let currentPage else { return }
            guard let widgetId = event.widgetId else { return }

            // Handle page title update
            if widgetId == effectivePageId(), let label = event.label {
                objectWillChange.send()
                currentPage.title = label
                return
            }

            // On servers that don't support invisible widgets, visibility changes require a full reload
            let supportsInvisible = serverProperties?.hasInvisibleWidgetSupport() ?? false
            if let eventVisibility = event.visibility,
               !supportsInvisible,
               let widget = currentPage.findWidget(byId: widgetId),
               eventVisibility != widget.visibility {
                logger.info("SSE visibility change on unsupported server – reloading")
                startPageHandling()
                return
            }

            // Apply the event to the widget tree
            if currentPage.apply(event: event) {
                objectWillChange.send()
                logger.debug("SSE applied widget update for \(widgetId)")
                isUpdating = false
            } else {
                logger.info("SSE widget not found – reloading")
                startPageHandling()
            }
        case let .unknown(raw):
            logger.debug("SSE unknown event: \(raw)")
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
