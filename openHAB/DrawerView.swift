// Copyright (c) 2010-2024 Contributors to the openHAB project
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

func deriveSitemaps(_ response: Data?) -> [OpenHABSitemap] {
    var sitemaps = [OpenHABSitemap]()

    if let response {
        do {
            os_log("Response will be decoded by JSON", log: .remoteAccess, type: .info)
            let sitemapsCodingData = try response.decoded(as: [OpenHABSitemap.CodingData].self)
            for sitemapCodingDatum in sitemapsCodingData {
                os_log("Sitemap %{PUBLIC}@", log: .remoteAccess, type: .info, sitemapCodingDatum.label)
                sitemaps.append(sitemapCodingDatum.openHABSitemap)
            }
        } catch {
            os_log("Should not throw %{PUBLIC}@", log: .notifications, type: .error, error.localizedDescription)
        }
    }

    return sitemaps
}

struct UiTile: Decodable {
    var name: String
    var url: String
    var imageUrl: String
}

struct DrawerView: View {
    @State private var sitemaps: [OpenHABSitemap] = []
    @State private var uiTiles: [OpenHABUiTile] = []
    @State private var drawerItems: [OpenHABDrawerItem] = []
    @State private var selectedSection: Int?

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

    var body: some View {
        List {
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

            Section(header: Text("Sitemaps")) {
                ForEach(sitemaps, id: \.name) { sitemap in
                    HStack {
                        let url = Endpoint.iconForDrawer(rootUrl: appData?.openHABRootUrl ?? "", icon: sitemap.icon).url
                        KFImage(url).placeholder { Image("openHABIcon").resizable() }
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: sitemapIconwidth)
                        Text(sitemap.label)
                    }
                    .onTapGesture {
                        dismiss()
                        onDismiss(.sitemap(sitemap.name))
                    }
                }
            }

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

                // check if we are using my.openHAB, add notifications menu item then
                // Actually this should better test whether the host of the remoteUrl is on openhab.org
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
        .listStyle(.inset)
        .onAppear(perform: loadData)
    }

    private func loadData() {
        // TODO: Replace network calls with appropriate @EnvironmentObject or other state management
        loadSitemaps()
        loadUiTiles()
    }

    private func loadSitemaps() {
        // Perform network call to load sitemaps and decode
        // Update the sitemaps state

        NetworkConnection.sitemaps(openHABRootUrl: appData?.openHABRootUrl ?? "") { response in
            switch response.result {
            case let .success(data):
                os_log("Sitemap response", log: .viewCycle, type: .info)

                sitemaps = deriveSitemaps(data)

                if sitemaps.last?.name == "_default", sitemaps.count > 1 {
                    sitemaps = Array(sitemaps.dropLast())
                }

                // Sort the sitemaps according to Settings selection.
                switch SortSitemapsOrder(rawValue: Preferences.sortSitemapsby) ?? .label {
                case .label: sitemaps.sort { $0.label < $1.label }
                case .name: sitemaps.sort { $0.name < $1.name }
                }

                drawerItems.removeAll()
            case let .failure(error):
                os_log("%{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
                drawerItems.removeAll()
            }
        }
    }

    private func loadUiTiles() {
        // Perform network call to load UI Tiles and decode
        // Update the uiTiles state
        NetworkConnection.uiTiles(openHABRootUrl: appData?.openHABRootUrl ?? "") { response in
            switch response.result {
            case .success:
                os_log("ui tiles response", log: .viewCycle, type: .info)
                guard let responseData = response.data else {
                    os_log("Error: did not receive data", log: OSLog.remoteAccess, type: .info)
                    return
                }
                do {
                    uiTiles = try JSONDecoder().decode([OpenHABUiTile].self, from: responseData)
                } catch {
                    os_log("Error: did not receive data %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, error.localizedDescription)
                }
            case let .failure(error):
                os_log("%{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
            }
        }
    }

    mutating func loadSettings() {
        openHABUsername = Preferences.username
        openHABPassword = Preferences.password
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

// #Preview {
//     DrawerView(onDismiss: {.webview -> Void})
// }
