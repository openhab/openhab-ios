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
    private var pageHandlingTask: Task<Void, Never>?
    private var connectionObserverTask: Task<Void, Never>?
    private var defaultSitemap = ""
    private var defaultSitemapLabel = ""
    @Published var pageId = ""
    private var isLinkedPage = false
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

    init() {
        loadSettings()
        // Observe connection changes (skip initial value) — initial load is triggered by .task in the view
        connectionObserverTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await connection in networkTracker.$activeConnection.values.dropFirst() {
                handleActiveConnectionChange(connection)
            }
        }
    }

    init(pageUrl: String, title: String, pageId: String = "") {
        loadSettings()
        isLinkedPage = true
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
        error = nil // Clear any previous errors when starting a new page handling session
        isLoading = true // Show redacted view immediately

        logger.info("🚀 Starting page load and long polling flow...")

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
                openHABRootUrl = configuration.url

                if openAPIService == nil {
                    openAPIService = try OpenAPIService(connectionConfiguration: configuration)
                }

                // Fetch sitemap label if we loaded from preferences (not from discovery)
                if defaultSitemapLabel.isEmpty {
                    await fetchSitemapLabel()
                }

                // 1. Initial page load (longPolling: false)
                let initialPage = try await openAPIService?.pollDataForPage(
                    sitemapname: defaultSitemap,
                    pageId: pageId,
                    longPolling: false
                )

                try Task.checkCancellation()

                if let page = initialPage {
                    updateUI(with: page)
                }
                isLoading = false

                // 2. Start long polling loop
                while !Task.isCancelled {
                    isUpdating = true
                    let page = try await openAPIService?.pollDataForPage(
                        sitemapname: defaultSitemap,
                        pageId: pageId,
                        longPolling: true
                    )
                    isUpdating = false
                    try Task.checkCancellation()

                    if let page {
                        updateUI(with: page)
                    }
                }

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

        // Skip if already connected to this URL — avoids restarting long-polling
        // when the NetworkTracker re-evaluates to the same connection
        guard openHABRootUrl != activeConnection.configuration.url else {
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

        do {
            // Setup the OpenAPI service based on the new connection
            openAPIService = try OpenAPIService(connectionConfiguration: connection.configuration)
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
        connectionObserverTask?.cancel()
        pageHandlingTask?.cancel()
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
