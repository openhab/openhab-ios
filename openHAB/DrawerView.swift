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

import Combine
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

struct DrawerView: View {
    @State private var sitemaps: [OpenHABSitemap] = []
    @State private var uiTiles: [OpenHABUiTile] = []
    @State private var selectedSection: Int?
    @State private var connectedUrl: String = "Not connected" // Default label text

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

    // Combine cancellable
    @State private var trackerCancellable: AnyCancellable?

    var body: some View {
        VStack {
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

            Spacer()

            // Display the connected URL
            HStack {
                Image(systemName: "cloud.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                Text(connectedUrl)
                    .font(.footnote)
            }
            .padding(.bottom, 5)
            .onAppear(perform: trackActiveServer)
            .onDisappear {
                trackerCancellable?.cancel()
            }
        }
    }

    private func trackActiveServer() {
        trackerCancellable = NetworkTracker.shared.$activeServer
            .receive(on: DispatchQueue.main)
            .sink { activeServer in
                if let activeServer {
                    connectedUrl = activeServer.url
                } else {
                    connectedUrl = NSLocalizedString("connecting", comment: "")
                }
            }
    }

    private func loadData() {
        loadSitemaps()
        loadUiTiles()
    }

    private func loadSitemaps() {
        NetworkConnection.sitemaps(openHABRootUrl: appData?.openHABRootUrl ?? "") { response in
            switch response.result {
            case let .success(data):
                os_log("Sitemap response", log: .viewCycle, type: .info)

                sitemaps = deriveSitemaps(data)

                if sitemaps.last?.name == "_default", sitemaps.count > 1 {
                    sitemaps = Array(sitemaps.dropLast())
                }

                switch SortSitemapsOrder(rawValue: Preferences.sortSitemapsby) ?? .label {
                case .label: sitemaps.sort { $0.label < $1.label }
                case .name: sitemaps.sort { $0.name < $1.name }
                }
            case let .failure(error):
                os_log("%{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
            }
        }
    }

    private func loadUiTiles() {
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
}

#Preview {
    DrawerView { _ in }
}
