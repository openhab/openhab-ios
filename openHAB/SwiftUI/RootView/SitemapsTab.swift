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
    @State private var selectedSitemap: SelectedSitemapIdentifier?
    @State private var sitemapForWatch: String?
    @StateObject private var viewModel = SitemapPageViewModel()
    
    private struct SelectedSitemapIdentifier: Identifiable, Hashable {
        let id = UUID()
        let name: String
    }

    @EnvironmentObject private var networkTracker: MainActorNetworkTracker

    @ScaledMetric private var iconWidth = 24.0

    var body: some View {
        NavigationStack {
            sitemapList
                .navigationTitle("Sitemaps")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(item: $selectedSitemap) { sitemapName in
                    SitemapNavigationView(viewModel: viewModel)
                }
        }
        .task {
            sitemapForWatch = await Preferences.shared.currentHomePreferences.sitemapForWatch
            await fetchSitemaps(activeConnection: networkTracker.activeConnection)
            let defaultSitemap = await Preferences.shared.currentHomePreferences.defaultSitemap
            if !defaultSitemap.isEmpty, sitemaps.contains(where: { $0.name == defaultSitemap }) {
                selectSitemap(defaultSitemap)
            }
        }
        .onReceive(networkTracker.$activeConnection) { activeConnection in
            Task {
                await fetchSitemaps(activeConnection: activeConnection)
            }
        }
        .onChange(of: resetTrigger) { _, _ in
            selectedSitemap = nil
        }
        .onChange(of: navigationCommand) { _, command in
            guard let command else { return }
            selectedSitemap = SelectedSitemapIdentifier(name: command.name)
            Task {
                await Preferences.shared.modifyActiveHome { preferences in
                    preferences.defaultSitemap = command.name
                }
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
        selectedSitemap = SelectedSitemapIdentifier(name: name)
        Task {
            await Preferences.shared.modifyActiveHome { preferences in
                preferences.defaultSitemap = name
            }
            await viewModel.pushSitemap(name: name, path: nil)
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
        let sitemapForWatchName, sitemapForWatchLabel: String
        if sitemap.name == sitemapForWatch {
            sitemapForWatch = nil
            sitemapForWatchName = ""
            sitemapForWatchLabel = ""
        } else {
            sitemapForWatch = sitemap.name
            sitemapForWatchName = sitemap.name
            sitemapForWatchLabel = sitemap.label
        }
        Task {
            await Preferences.shared.modifyActiveHome { prefs in
                prefs.sitemapForWatch = sitemapForWatchName
                prefs.sitemapForWatchLabel = sitemapForWatchLabel
            }
        }
    }
}

