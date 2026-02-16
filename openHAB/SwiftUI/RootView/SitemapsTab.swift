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

import Kingfisher
import OpenHABCore
import os.log
import SFSafeSymbols
import SwiftUI

struct SitemapNavigationCommand: Equatable {
    let name: String
    let widgetId: String?
    let id = UUID()
}

struct SitemapsTab: View {
    var resetTrigger: Int = 0
    @Binding var navigationCommand: SitemapNavigationCommand?

    @State private var sitemaps: [OpenHABSitemap] = []
    @State private var selectedSitemap: String?
    @State private var sitemapForWatch: String?
    @StateObject private var viewModel = SitemapPageViewModel()

    @EnvironmentObject private var networkTracker: MainActorNetworkTracker

    @ScaledMetric private var iconWidth = 24.0

    var body: some View {
        NavigationStack {
            Group {
                if selectedSitemap != nil {
                    SitemapNavigationContent(viewModel: viewModel)
                } else {
                    sitemapList
                }
            }
            .navigationTitle(selectedSitemap != nil ? viewModel.pageTitle : "Sitemaps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selectedSitemap != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            self.selectedSitemap = nil
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemSymbol: .chevronBackward)
                                Text("Sitemaps")
                            }
                        }
                    }
                }
            }
        }
        .task {
            sitemapForWatch = await Preferences.shared.currentHomePreferences.sitemapForWatch
            await fetchSitemaps(activeConnection: networkTracker.activeConnection)
            autoSelectSitemap()
        }
        .onReceive(networkTracker.$activeConnection) { activeConnection in
            Task {
                await fetchSitemaps(activeConnection: activeConnection)
            }
        }
        .onChange(of: resetTrigger) { _, _ in
            withAnimation {
                selectedSitemap = nil
            }
        }
        .onChange(of: navigationCommand) { _, command in
            guard let command else { return }
            selectedSitemap = command.name
            Preferences.shared.modifyActiveHome { preferences in
                preferences.defaultSitemap = command.name
            }
            Task {
                await viewModel.pushSitemap(name: command.name, path: command.widgetId)
            }
            navigationCommand = nil
        }
    }

    private var sitemapList: some View {
        List {
            ForEach(sitemaps, id: \.name) { sitemap in
                Button {
                    selectSitemap(sitemap.name)
                } label: {
                    HStack {
                        sitemapIcon(for: sitemap)
                            .frame(width: iconWidth, height: iconWidth)
                        Text(sitemap.label)
                        if sitemap.name == sitemapForWatch {
                            Spacer()
                            Image(systemSymbol: .applewatchWatchface)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onTapGesture(count: 2) { toggleWatchSitemap(sitemap) }
            }
        }
    }

    private func selectSitemap(_ name: String) {
        selectedSitemap = name
        Preferences.shared.modifyActiveHome { preferences in
            preferences.defaultSitemap = name
        }
        Task {
            await viewModel.pushSitemap(name: name, path: nil)
        }
    }

    private func autoSelectSitemap() {
        let defaultSitemap = Preferences.shared.currentHomePreferences.defaultSitemap
        if !defaultSitemap.isEmpty, sitemaps.contains(where: { $0.name == defaultSitemap }) {
            selectSitemap(defaultSitemap)
        }
    }

    private func fetchSitemaps(activeConnection: ConnectionInfo?) async {
        guard let activeConnection else { return }
        do {
            let openAPIService = try OpenAPIService(connectionConfiguration: activeConnection.configuration)
            var fetched = try await openAPIService.openHABSitemaps()
            if fetched.last?.name == "_default", fetched.count > 1 {
                fetched = Array(fetched.dropLast())
            }
            let sortSitemapsBy = await Preferences.shared.currentHomePreferences.sortSitemapsBy
            switch SortSitemapsOrder(rawValue: sortSitemapsBy) ?? .label {
            case .label:
                fetched.sort { $0.label < $1.label }
            case .name:
                fetched.sort { $0.name < $1.name }
            }
            sitemaps = fetched
        } catch {
            Logger.drawerView.error("Failed to fetch sitemaps: \(error.localizedDescription)")
            sitemaps = []
        }
    }

    private func sitemapIcon(for sitemap: OpenHABSitemap) -> some View {
        Group {
            if sitemap.icon.isEmpty {
                Image("openHABIcon").resizable()
            } else {
                let url = Endpoint.iconForDrawer(
                    rootUrl: networkTracker.activeConnection?.configuration.url ?? "",
                    icon: sitemap.icon
                ).url
                KFImage(url)
                    .placeholder { Image("openHABIcon").resizable() }
                    .resizable()
            }
        }
        .aspectRatio(contentMode: .fit)
    }

    private func toggleWatchSitemap(_ sitemap: OpenHABSitemap) {
        Preferences.shared.modifyActiveHome { prefs in
            if sitemap.name == sitemapForWatch {
                sitemapForWatch = nil
                prefs.sitemapForWatch = ""
                prefs.sitemapForWatchLabel = ""
            } else {
                sitemapForWatch = sitemap.name
                prefs.sitemapForWatch = sitemap.name
                prefs.sitemapForWatchLabel = sitemap.label
            }
        }
    }
}

/// Inner content view that wraps SitemapPageView without its own NavigationStack
private struct SitemapNavigationContent: View {
    @ObservedObject var viewModel: SitemapPageViewModel

    var body: some View {
        let page = SitemapPageView(viewModel: viewModel)
        if viewModel.showSearchField {
            page
                .searchable(text: $viewModel.searchText, prompt: Text(NSLocalizedString("search_items", comment: "")))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        } else {
            page
        }
    }
}
