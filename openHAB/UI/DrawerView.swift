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

import Combine
import CommonUI
import Kingfisher
import OpenHABCore
import os.log
import SafariServices
import SFSafeSymbols
import SwiftUI

class CurrentViewState: ObservableObject {
    @Published var isWebViewActive = false
}

enum DrawerViewError: Error, CustomDebugStringConvertible {
    case noRootURL

    var debugDescription: String {
        switch self {
        case .noRootURL:
            "No root URL"
        }
    }
}

enum DrawerFetchResult<Value> {
    case value(Value)
    case cancelled
    case failed(any Error)
}

@MainActor
enum DrawerFetch {
    static func sitemaps(sortOrder: SortSitemapsOrder,
                         fetch: () async throws -> [OpenHABSitemap]) async -> DrawerFetchResult<[OpenHABSitemap]> {
        do {
            var sitemaps = try await fetch()
            try Task.checkCancellation()
            if sitemaps.last?.name == "_default", sitemaps.count > 1 {
                sitemaps = Array(sitemaps.dropLast())
            }
            switch sortOrder {
            case .label:
                sitemaps.sort { $0.label < $1.label }
            case .name:
                sitemaps.sort { $0.name < $1.name }
            }
            try Task.checkCancellation()
            return .value(sitemaps)
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failed(error)
        }
    }

    static func uiTiles(
        fetch: () async throws -> [OpenHABUiTile]
    ) async -> DrawerFetchResult<[OpenHABUiTile]> {
        do {
            let uiTiles = try await fetch()
            try Task.checkCancellation()
            return .value(uiTiles)
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failed(error)
        }
    }
}

// Display the connected URL
struct ConnectionView: View {
    @StateObject private var networkTracker = MainActorNetworkTracker.shared

    var body: some View {
        HStack {
            if let activeConnection = networkTracker.activeConnection {
                Image(systemSymbol: .cloudFill)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                Text(activeConnection.configuration.url).font(.footnote)
            } else {
                Image(systemSymbol: .exclamationmarkIcloudFill)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                Text("connecting").font(.footnote)
            }
        }
    }
}

struct DrawerView: View {
    @State private var sitemaps: [OpenHABSitemap] = []
    @State private var uiTiles: [OpenHABUiTile] = []
    @State private var selectedSection: Int?
    @State private var connectedUrl = "Not connected" // Default label text

    @EnvironmentObject private var networkTracker: MainActorNetworkTracker
    @EnvironmentObject private var currentViewState: CurrentViewState

    var onDismiss: (TargetController) -> Void
    @Environment(\.dismiss) private var dismiss

    @ScaledMetric var iconWidth = 20.0

    @State private var sitemapForWatch: String?

    var mainSection: some View {
        Section(header: Text("Main")) {
            menuEntry(image: Image("openHABIcon").resizable(), goTo: .webview) {
                HStack {
                    Text("Home").accessibilityIdentifier("Home")
                    if currentViewState.isWebViewActive {
                        Spacer()
                        Image(systemSymbol: .arrowClockwise)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }

    var tilesSection: some View {
        Section(header: Text("Tiles")) {
            ForEach(uiTiles, id: \.url) { tile in
                menuEntry(
                    image: ImageView(url: tile.imageUrl),
                    goTo: .tile(tile.url)
                ) {
                    Text(tile.name)
                }
            }
        }
    }

    var sitemapsSection: some View {
        Section(header: Text("Sitemaps")) {
            ForEach(sitemaps, id: \.name) { sitemap in
                menuEntry(
                    image: sitemapIcon(for: sitemap),
                    goTo: .sitemap(sitemap.name)
                ) {
                    HStack {
                        Text(sitemap.label)
                        if sitemap.name == sitemapForWatch {
                            Spacer()
                            Image(systemSymbol: .applewatchWatchface)
                        }
                    }
                }
                .onTapGesture(count: 2) { toggleWatchSitemap(sitemap) }
            }
        }
    }

    var systemSection: some View {
        Section(header: Text("System")) {
            systemMenuEntry(image: .gear, text: "settings", goTo: .settings)
            if Preferences.shared.getNotificationConnection() != nil,
               !Preferences.shared.currentHomePreferences.demomode {
                systemMenuEntry(image: .bell, text: "notifications", goTo: .notifications)
            }
            systemMenuEntry(image: .house, text: "Manage Homes", goTo: .homeSelection)
        }
    }

    var body: some View {
        VStack {
            List {
                mainSection
                sitemapsSection
                tilesSection
                systemSection
            }
            .listStyle(.inset)

            Spacer()
            ConnectionView()
                .padding(.bottom, 5)
        }
        .listStyle(.inset)
        .task(id: networkTracker.activeConnection) {
            await updateSitemapsAndUITiles(activeConnection: networkTracker.activeConnection)
            sitemapForWatch = Preferences.shared.currentHomePreferences.sitemapForWatch
        }
    }

    private func menuEntry(image: Image, text: Text, goTo target: TargetController) -> some View {
        Button {
            onDismiss(target)
        } label: {
            HStack {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconWidth, height: iconWidth)
                text
            }
        }
        .buttonStyle(.plain)
    }

    private func menuEntry(image: some View,
                           goTo target: TargetController,
                           @ViewBuilder label: () -> some View) -> some View {
        Button {
            onDismiss(target)
        } label: {
            HStack {
                image
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconWidth, height: iconWidth)
                label()
            }
            .contentShape(Rectangle()) // entire row tappable
        }
        .buttonStyle(.plain)
    }

    func systemMenuEntry(image: SFSymbol, text: String, goTo target: TargetController) -> some View {
        menuEntry(image: Image(systemSymbol: image), goTo: target) {
            Text(LocalizedStringKey(text))
                .accessibilityLabel(text)
        }
    }

    func sitemapIcon(for sitemap: OpenHABSitemap) -> some View {
        Group {
            if sitemap.icon.isEmpty {
                Image("openHABIcon").resizable()
            } else {
                let url = Endpoint.iconForDrawer(
                    rootUrl: networkTracker.activeConnection?.configuration.url ?? "",
                    icon: sitemap.icon
                ).url
                KFImage(url)
                    .withOpenHABCredentials(for: networkTracker.activeConnection)
                    .placeholder { Image("openHABIcon").resizable() }
                    .resizable()
            }
        }
        .aspectRatio(contentMode: .fit)
    }

    func toggleWatchSitemap(_ sitemap: OpenHABSitemap) {
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

    private func updateSitemapsAndUITiles(activeConnection: ConnectionInfo?) async {
        guard let activeConnection else { return }

        do {
            let openAPIService = try OpenAPIService(connectionConfiguration: activeConnection.configuration)

            let sortSitemapsBy = Preferences.shared.currentHomePreferences.sortSitemapsBy
            let sortOrder = SortSitemapsOrder(rawValue: sortSitemapsBy) ?? .label
            let sitemapsResult = await DrawerFetch.sitemaps(sortOrder: sortOrder) {
                try await openAPIService.openHABSitemaps()
            }
            switch sitemapsResult {
            case let .value(fetchedSitemaps):
                sitemaps = fetchedSitemaps
            case .cancelled:
                return
            case let .failed(error):
                Logger.drawerView.error("Failed to fetch sitemaps: \(error.localizedDescription)")
                sitemaps = []
            }

            let tilesResult = await DrawerFetch.uiTiles {
                try await openAPIService.getUITiles()
            }
            switch tilesResult {
            case let .value(fetchedUITiles):
                uiTiles = fetchedUITiles
                Logger.drawerView.info("Fetched UI tiles successfully")
            case .cancelled:
                return
            case let .failed(error):
                Logger.drawerView.error("Failed to fetch UI tiles: \(error.localizedDescription)")
                uiTiles = []
            }

        } catch is CancellationError {
            return
        } catch {
            Logger.drawerView.error("Failed to initialize OpenAPIService: \(error.localizedDescription)")
            sitemaps = []
            uiTiles = []
        }
    }
}

#Preview("WebView Active") {
    let networkTracker = MainActorNetworkTracker.shared
    let currentViewState = CurrentViewState()
    currentViewState.isWebViewActive = true
    return DrawerView { _ in }
        .environmentObject(networkTracker)
        .environmentObject(currentViewState)
}

#Preview("WebView Inactive") {
    let networkTracker = MainActorNetworkTracker.shared
    let currentViewState = CurrentViewState()
    currentViewState.isWebViewActive = false
    return DrawerView { _ in }
        .environmentObject(networkTracker)
        .environmentObject(currentViewState)
}
