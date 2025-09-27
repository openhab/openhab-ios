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
import Kingfisher
import OpenHABCore
import os.log
import SafariServices
import SFSafeSymbols
import SwiftUI

private let logger = Logger(subsystem: "org.openhab.app", category: "DrawerView")

enum DrawerViewError: Error, CustomDebugStringConvertible {
    case noRootURL

    var debugDescription: String {
        switch self {
        case .noRootURL:
            "No root URL"
        }
    }
}

struct ImageView: View {
    let url: String

    @EnvironmentObject var networkTracker: MainActorNetworkTracker

    var body: some View {
        if !url.isEmpty {
            switch url {
            case _ where url.hasPrefix("data:image"):
                let provider = Base64ImageDataProvider(base64String: url.deletingPrefix("data:image/png;base64,"), cacheKey: UUID().uuidString)
                return KFImage(source: .provider(provider)).resizable()
            case _ where url.hasPrefix("http"):
                return KFImage(URL(string: url)).resizable()
            default:
                let builtURL = Endpoint.resource(
                    openHABRootUrl: networkTracker.activeConnection?.configuration.url ?? "",
                    path: url.prepare()
                ).url
                return KFImage(builtURL).resizable()
            }
        } else {
            // This will always fallback to placeholder
            return KFImage(URL(string: "bundle://openHABIcon")).placeholder { Image("openHABIcon").resizable() }
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

    var onDismiss: (TargetController) -> Void
    @Environment(\.dismiss) private var dismiss

    @ScaledMetric var iconWidth = 20.0

    @State private var sitemapForWatch: String?

    var mainSection: some View {
        Section(header: Text("Main")) {
            menuEntry(image: Image("openHABIcon").resizable(), goTo: .webview) {
                Text("Home").accessibilityIdentifier("Home")
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
                tilesSection
                sitemapsSection
                systemSection
            }
            .listStyle(.inset)

            Spacer()
            ConnectionView()
                .padding(.bottom, 5)
        }
        .listStyle(.inset)
        .task {
            let activeConnection = networkTracker.activeConnection
            await updateSitemapsAndUITiles(activeConnection: activeConnection)
            sitemapForWatch = Preferences.shared.currentHomePreferences.sitemapForWatch
        }
        .onReceive(networkTracker.$activeConnection) { activeConnection in
            Task {
                await updateSitemapsAndUITiles(activeConnection: activeConnection)
            }
        }
    }

    private func menuEntry(image: Image, text: Text, goTo target: TargetController) -> some View {
        HStack {
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconWidth, height: iconWidth)
            text
        }
        .onTapGesture {
            dismiss()
            onDismiss(target)
        }
    }

    private func menuEntry(image: some View,
                           goTo target: TargetController,
                           @ViewBuilder label: () -> some View) -> some View {
        HStack {
            image
                .aspectRatio(contentMode: .fit)
                .frame(width: iconWidth, height: iconWidth)
            label()
        }
        .contentShape(Rectangle()) // entire row tappable
        .onTapGesture {
            dismiss()
            onDismiss(target)
        }
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

            do {
                sitemaps = try await openAPIService.openHABSitemaps()
                if sitemaps.last?.name == "_default", sitemaps.count > 1 {
                    sitemaps = Array(sitemaps.dropLast())
                }
                let sortSitemapsBy = Preferences.shared.currentHomePreferences.sortSitemapsBy
                switch SortSitemapsOrder(rawValue: sortSitemapsBy) ?? .label {
                case .label:
                    sitemaps.sort { $0.label < $1.label }
                case .name:
                    sitemaps.sort { $0.name < $1.name }
                }

            } catch {
                logger.error("Failed to fetch sitemaps: \(error.localizedDescription)")
                sitemaps = []
            }

            do {
                uiTiles = try await openAPIService.getUITiles()
                logger.info("Fetched UI tiles successfully")
            } catch {
                logger.error("Failed to fetch UI tiles: \(error.localizedDescription)")
                uiTiles = []
            }

        } catch {
            logger.error("Failed to initialize OpenAPIService: \(error.localizedDescription)")
            sitemaps = []
            uiTiles = []
        }
    }
}

#Preview {
    let networkTracker = MainActorNetworkTracker.shared
    DrawerView { _ in }
        .environmentObject(networkTracker)
}
