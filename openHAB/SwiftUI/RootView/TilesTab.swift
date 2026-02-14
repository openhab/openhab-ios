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

import OpenHABCore
import os.log
import SFSafeSymbols
import SwiftUI

struct TilesTab: View {
    @State private var uiTiles: [OpenHABUiTile] = []
    @State private var selectedTileURL: IdentifiableURL?

    @EnvironmentObject private var networkTracker: MainActorNetworkTracker

    @ScaledMetric private var iconWidth = 24.0

    var body: some View {
        NavigationStack {
            List {
                ForEach(uiTiles, id: \.url) { tile in
                    Button {
                        openTile(tile)
                    } label: {
                        HStack {
                            ImageView(url: tile.imageUrl)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: iconWidth, height: iconWidth)
                            Text(tile.name)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Tiles")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await fetchTiles(activeConnection: networkTracker.activeConnection)
        }
        .onReceive(networkTracker.$activeConnection) { activeConnection in
            Task {
                await fetchTiles(activeConnection: activeConnection)
            }
        }
        .sheet(item: $selectedTileURL) { item in
            SafariView(url: item.url)
        }
    }

    func resetToRoot() {
        selectedTileURL = nil
    }

    private func openTile(_ tile: OpenHABUiTile) {
        let urlString = tile.url
        guard !urlString.isEmpty else { return }

        let url: URL?
        if urlString.hasPrefix("http") || urlString.hasPrefix("https") {
            url = URL(string: urlString)
        } else {
            guard let rootUrl = networkTracker.activeConnection?.configuration.url else {
                Logger.viewController.error("openTileURL failed: no active connection URL")
                return
            }
            url = Endpoint.resource(openHABRootUrl: rootUrl, path: urlString.prepare()).url
        }

        if let url {
            selectedTileURL = IdentifiableURL(url: url)
        }
    }

    private func fetchTiles(activeConnection: ConnectionInfo?) async {
        guard let activeConnection else { return }
        do {
            let openAPIService = try OpenAPIService(connectionConfiguration: activeConnection.configuration)
            uiTiles = try await openAPIService.getUITiles()
            Logger.drawerView.info("Fetched UI tiles successfully")
        } catch {
            Logger.drawerView.error("Failed to fetch UI tiles: \(error.localizedDescription)")
            uiTiles = []
        }
    }
}

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}
