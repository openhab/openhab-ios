// Copyright (c) 2010-2025 Contributors to the openHAB project
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
    @Published var openHABRootUrl: String?

    @ObservedObject var networkTracker = NetworkTracker.shared
    private var openAPIService: OpenAPIService?
    private var activeConnectionInfo: ConnectionInfo?
    private var pageHandlingTask: Task<Void, Never>?
    private var defaultSitemap = ""
    @Published var pageId = ""
    private var isLinkedPage = false

    var relevantWidgets: [OpenHABWidget] {
        var flattenedWidgets = [OpenHABWidget]()
        flattenedWidgets.flatten(currentPage?.widgets ?? [])

        guard !searchText.isEmpty else { return flattenedWidgets }

        return flattenedWidgets.filter {
            $0.label.lowercased().contains(searchText.lowercased()) && $0.type != .frame
        }
    }

    var pageTitle: String {
        currentPage?.title ?? (defaultSitemap.isEmpty ? "Sitemap" : defaultSitemap)
    }

    var isLinked: Bool {
        isLinkedPage
    }

    init() {
        loadSettings()
        setupActiveConnectionObserver()
    }

    init(pageUrl: String, title: String, pageId: String = "") {
        loadSettings()
        setupActiveConnectionObserver()
        isLinkedPage = true

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
        defaultSitemap = Preferences.currentHomePreferences.defaultSitemap
    }

    func startPageHandling() {
        pageHandlingTask?.cancel()

        logger.info("🚀 Starting page load and long polling flow...")

        pageHandlingTask = Task {
            // If no default sitemap is set, try to discover and auto-select one
            if defaultSitemap.isEmpty {
                await discoverAndSelectSitemap()
            }

            guard !defaultSitemap.isEmpty else {
                logger.error("startPageHandling: Cannot run with empty sitemap after discovery")
                return
            }
            do {
                guard let activeConnection = await NetworkTracker.shared.waitForActiveConnection() else {
                    logger.error("Failed to establish connection within timeout")
                    return
                }
                let configuration = activeConnection.configuration

                if openAPIService == nil {
                    openAPIService = try OpenAPIService(connectionConfiguration: configuration)
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

                // 2. Start long polling loop
                while !Task.isCancelled {
                    let page = try await openAPIService?.pollDataForPage(
                        sitemapname: defaultSitemap,
                        pageId: pageId,
                        longPolling: true
                    )
                    try Task.checkCancellation()

                    if let page {
                        updateUI(with: page)
                    }
                }

            } catch is CancellationError {
                logger.info("🔁 pageHandlingTask was cancelled")
            } catch let error as DecodingError {
                logger.error("Decoding error: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = SitemapPageError.serviceUnavailable
                }
            } catch let error as ClientError {
                if let urlError = error.underlyingError as? URLError, urlError.code == .cancelled {
                    logger.info("Task cancelled (URLError: cancelled)")
                } else if let urlError = error.underlyingError as? URLError, urlError.code == .timedOut {
                    logger.info("Task timed out (URLError: timedOut)")
                } else {
                    logger.error("ClientError: \(error.localizedDescription)")
                    await MainActor.run {
                        self.error = SitemapPageError.serviceUnavailable
                    }
                }
            } catch let openAPIError as OpenAPIServiceError {
                logger.error("OpenAPIServiceError: \(openAPIError.localizedDescription)")
            } catch {
                logger.error("❌ Unhandled pageHandlingTask error: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = SitemapPageError.serviceUnavailable
                }
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

        let page = try await service.pollDataForPage(
            sitemapname: defaultSitemap,
            pageId: pageId,
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

    func widgetTapped(_ widget: OpenHABWidget) {
        if let linkedPage = widget.linkedPage {
            // Push a new view (handled in the SwiftUI view)
        }
        // handle other widget types
    }

    @MainActor
    func pushSitemap(name: String, path: String?) async {
        defaultSitemap = name
        pageId = path ?? ""
        startPageHandling()
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
                // swiftformat:disable:next redundantSelf
                logger.info("Auto-selected single sitemap: \(self.defaultSitemap)")

                // Save as default for future launches
                Preferences.modifyActiveHome { homePreferences in
                    homePreferences.defaultSitemap = defaultSitemap
                }
            case 2...:
                // Multiple sitemaps available - select the first one
                defaultSitemap = filteredSitemaps[0].name
                // swiftformat:disable:next redundantSelf
                logger.info("Auto-selected first sitemap from \(filteredSitemaps.count) available: \(self.defaultSitemap)")

                // Save as default for future launches
                Preferences.modifyActiveHome { homePreferences in
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

        Task {
            await handleActiveConnection(activeConnection)
        }
    }

    private func handleActiveConnection(_ connection: ConnectionInfo) async {
        // Save the active connection information
        activeConnectionInfo = connection
        openHABRootUrl = connection.configuration.url

        do {
            // Setup the OpenAPI service based on the new connection
            openAPIService = try OpenAPIService(connectionConfiguration: connection.configuration)
            // Reload the sitemap data
            await selectSitemap()
        } catch {
            self.error = error as? any LocalizedError
        }
    }

    func selectSitemap() async {
        await reload()
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
    }
}

extension Published.Publisher {
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
