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
import SwiftUI

@MainActor
class SitemapPageViewModel: ObservableObject {
    @Published var currentPage: OpenHABPage?
    @Published var filteredWidgets: [OpenHABWidget] = []
    @Published var searchText: String = ""
    @Published var error: LocalizedError?
    @Published var isLoading: Bool = false

    private var openAPIService: OpenAPIService?
    private var activeConnectionInfo: ConnectionInfo?
    private var pageHandlingTask: Task<Void, Never>?
    private var defaultSitemap: String = ""
    private var pageId: String = ""

    init() {
        loadSettings()
    }

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

    func loadSettings() {
        defaultSitemap = Preferences.defaultSitemap
    }

    func startPolling() async {
        guard pageHandlingTask == nil else { return }

        pageHandlingTask = Task {
            await reload()

            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 20 * 1_000_000_000) // 20s polling
                    try await loadCurrentPage()
                } catch {
                    self.error = error as? LocalizedError
                }
            }
        }
    }

    func reload() async {
        do {
            isLoading = true
            try await setupConnection()
            try await loadCurrentPage()
        } catch {
            self.error = error as? LocalizedError
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

        currentPage = page
        filterWidgets()
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
        await reload()
    }
}

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
