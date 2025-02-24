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

import Kingfisher
import OpenHABCore
import os.log
import SafariServices
import SFSafeSymbols
import SwiftUI

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

    // App wide data access
    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

    var body: some View {
        if !url.isEmpty {
            switch url {
            case _ where url.hasPrefix("data:image"):
                let provider = Base64ImageDataProvider(base64String: url.deletingPrefix("data:image/png;base64,"), cacheKey: UUID().uuidString)
                return KFImage(source: .provider(provider)).resizable()
            case _ where url.hasPrefix("http"):
                return KFImage(URL(string: url)).resizable()
            default:
                let builtURL = Endpoint.resource(openHABRootUrl: appData?.openHABRootUrl ?? "", path: url.prepare()).url
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
    @ObservedObject private var networkTracker = NetworkTracker.shared

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
    struct MainSectionView: View {
        var openHABIconwidth: CGFloat
        var onDismiss: (TargetController) -> Void
        var dismiss: DismissAction

        var body: some View {
            Section(header: Text("Main")) {
                HStack {
                    Image("openHABIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: openHABIconwidth)
                    Text("Home")
                }
                .onTapGesture {
                    dismiss()
                    onDismiss(.webview)
                }
            }
        }
    }

    struct TilesSectionView: View {
        var uiTiles: [OpenHABUiTile]
        var tilesIconwidth: CGFloat
        var onDismiss: (TargetController) -> Void
        var dismiss: DismissAction

        var body: some View {
            Section(header: Text("Tiles")) {
                ForEach(uiTiles, id: \.url) { tile in
                    HStack {
                        ImageView(url: tile.imageUrl)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: tilesIconwidth)
                        Text(tile.name)
                    }
                    .onTapGesture {
                        dismiss()
                        onDismiss(.tile(tile.url))
                    }
                }
            }
        }
    }

    //  Handle double-tap gesture for selecting or deselecting the sitemap for the watch
    struct SitemapsSectionView: View {
        var sitemaps: [OpenHABSitemap]
        var sitemapIconwidth: CGFloat
        var appData: OpenHABDataObject?
        @Binding var sitemapForWatch: String?
        var onDismiss: (TargetController) -> Void
        var dismiss: DismissAction

        var body: some View {
            Section(header: Text("Sitemaps")) {
                ForEach(sitemaps, id: \.name) { sitemap in
                    SitemapRowView(
                        sitemap: sitemap,
                        sitemapIconwidth: sitemapIconwidth,
                        appData: appData,
                        isWatchSitemap: sitemap.name == sitemapForWatch,
                        onDismiss: onDismiss,
                        dismiss: dismiss
                    )
                    .onTapGesture(count: 2) {
                        if sitemap.name == sitemapForWatch {
                            sitemapForWatch = nil
                            Preferences.sitemapForWatch = ""
                        } else {
                            sitemapForWatch = sitemap.name
                            Preferences.sitemapForWatch = sitemap.name
                        }
                    }
                }
            }
        }
    }

    struct SitemapRowView: View {
        var sitemap: OpenHABSitemap
        var sitemapIconwidth: CGFloat
        var appData: OpenHABDataObject?
        var isWatchSitemap: Bool
        var onDismiss: (TargetController) -> Void
        var dismiss: DismissAction

        var body: some View {
            HStack {
                let url = Endpoint.iconForDrawer(rootUrl: appData?.openHABRootUrl ?? "", icon: sitemap.icon).url
                KFImage(url).placeholder { Image("openHABIcon").resizable() }
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: sitemapIconwidth)
                Text(sitemap.label)
                if isWatchSitemap {
                    Spacer()
                    Image(systemSymbol: .applewatchWatchface)
                }
            }
            .onTapGesture {
                dismiss()
                onDismiss(.sitemap(sitemap.name))
            }
        }
    }

    struct SystemSectionView: View {
        var openHABIconwidth: CGFloat
        var onDismiss: (TargetController) -> Void
        var dismiss: DismissAction

        var body: some View {
            Section(header: Text("System")) {
                HStack {
                    Image(systemSymbol: .gear)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: openHABIconwidth)
                    Text(LocalizedStringKey("settings"))
                }
                .onTapGesture {
                    dismiss()
                    onDismiss(.settings)
                }

                if Preferences.remoteUrl.contains("openhab.org"), !Preferences.demomode {
                    HStack {
                        Image(systemSymbol: .bell)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: openHABIconwidth)
                        Text(LocalizedStringKey("notifications"))
                    }
                    .onTapGesture {
                        dismiss()
                        onDismiss(.notifications)
                    }
                }
            }
        }
    }

    @State private var sitemaps: [OpenHABSitemap] = []
    @State private var uiTiles: [OpenHABUiTile] = []
    @State private var selectedSection: Int?
    @State private var connectedUrl: String = "Not connected" // Default label text
    @ObservedObject private var networkTracker = NetworkTracker.shared

    var openHABUsername = ""
    var openHABPassword = ""

    var onDismiss: (TargetController) -> Void
    @Environment(\.dismiss) private var dismiss

    // App wide data access
    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

    @ScaledMetric var openHABIconwidth = 20.0
    @ScaledMetric var tilesIconwidth = 20.0
    @ScaledMetric var sitemapIconwidth = 20.0

    @State private var sitemapForWatch: String?

    var body: some View {
        VStack {
            List {
                MainSectionView(openHABIconwidth: openHABIconwidth, onDismiss: onDismiss, dismiss: dismiss)

                TilesSectionView(uiTiles: uiTiles, tilesIconwidth: tilesIconwidth, onDismiss: onDismiss, dismiss: dismiss)

                SitemapsSectionView(sitemaps: sitemaps, sitemapIconwidth: sitemapIconwidth, appData: appData, sitemapForWatch: $sitemapForWatch, onDismiss: onDismiss, dismiss: dismiss)

                SystemSectionView(openHABIconwidth: openHABIconwidth, onDismiss: onDismiss, dismiss: dismiss)
            }
            .listStyle(.inset)

            Spacer()
            ConnectionView()
                .padding(.bottom, 5)
        }
        .listStyle(.inset)
        .task {
            let openAPIService = await OpenAPIService()
            Task {
                do {
                    guard let url = URL(string: appData?.openHABRootUrl ?? "") else { throw DrawerViewError.noRootURL }
                    await openAPIService.updateBaseURL(with: url)

                    sitemaps = try await openAPIService.openHABSitemaps()
                    if sitemaps.last?.name == "_default", sitemaps.count > 1 {
                        sitemaps = Array(sitemaps.dropLast())
                    }
                    // Sort the sitemaps according to Settings selection.
                    switch SortSitemapsOrder(rawValue: Preferences.sortSitemapsby) ?? .label {
                    case .label: sitemaps.sort { $0.label < $1.label }
                    case .name: sitemaps.sort { $0.name < $1.name }
                    }

                } catch {
                    os_log("%{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
                    sitemaps = []
                }
            }

            Task {
                do {
                    guard let url = URL(string: appData?.openHABRootUrl ?? "") else { throw DrawerViewError.noRootURL }
                    await openAPIService.updateBaseURL(with: url)

                    uiTiles = try await openAPIService.getUITiles()
                    os_log("ui tiles response", log: .viewCycle, type: .info)
                } catch {
                    os_log("%{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
                    uiTiles = []
                }
            }
        }
    }
}

#Preview {
    DrawerView { _ in }
}
