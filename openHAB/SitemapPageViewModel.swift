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
    @Published var filteredWidgets: [OpenHABWidget] = []
    @Published var searchText = ""
    @Published var error: (any LocalizedError)?
    @Published var isLoading = false
    @Published var openHABRootUrl: String?

    private var openAPIService: OpenAPIService?
    private var activeConnectionInfo: ConnectionInfo?
    private var pageHandlingTask: Task<Void, Never>?
    private var defaultSitemap = ""
    private var pageId = ""
    private var trackerTask: Task<Void, Never>?

    var relevantWidgets: [OpenHABWidget] {
        if searchText.isEmpty {
            currentPage?.widgets ?? []
        } else {
            filteredWidgets
        }
    }

    var pageTitle: String {
        currentPage?.title.components(separatedBy: "[")[0] ?? "Sitemap"
    }

    init() {
        loadSettings()
        startWatchingActiveServer()
    }

    func loadSettings() {
        defaultSitemap = Preferences.defaultSitemap
    }

    func startPageHandling() {
        pageHandlingTask?.cancel()

        guard !defaultSitemap.isEmpty else {
            logger.error("startPageHandling: Cannot run with empty sitemap")
            return
        }

        logger.info("🚀 Starting page load and long polling flow...")

        pageHandlingTask = Task {
            do {
                // Setup service if needed
//                if openAPIService == nil {
//                    guard let activeConnection = NetworkTracker.shared.activeConnection else {
//                        throw SitemapPageError.noActiveConnection
//                    }
//                    openAPIService = try OpenAPIService(
//                        connectionConfiguration: activeConnection.configuration
//                    )
//                }

                guard let configuration = NetworkTracker.shared.activeConnection?.configuration else {
                    throw NetworkTrackerError.noActiveConnection
                }

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
        filterWidgets()
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
        filterWidgets()
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

    func filterWidgets() {
        if searchText.isEmpty {
            filteredWidgets = []
        } else {
            filteredWidgets = currentPage?.widgets.filter {
                $0.label.lowercased().contains(searchText.lowercased()) && $0.type != .frame
            } ?? []
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
        await startPageHandling()
    }

    deinit {
        trackerTask?.cancel()
    }

    func startWatchingActiveServer() {
        trackerTask = Task {
            for await activeConnection in NetworkTracker.shared.$activeConnection.stream() {
                if let activeConnection {
                    logger.info("Tracker URL \(activeConnection.configuration.url)")
                    await handleActiveConnection(activeConnection)
                    break
                }
            }
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
                os_log("SitemapPageViewModel: Successfully sent command %{PUBLIC}@ to %{PUBLIC}@", log: .default, type: .info, command, itemname)
            } catch {
                os_log("SitemapPageViewModel: Failed to send command %{PUBLIC}@ to %{PUBLIC}@ — %{PUBLIC}@", log: .default, type: .error, command, itemname, error.localizedDescription)
            }
        }
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
