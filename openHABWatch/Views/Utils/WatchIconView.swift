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

import CommonUI
import Kingfisher
import OpenHABCore
import os.log
internal import SFSafeSymbols
import SwiftUI

struct IconRenderModel: Equatable {
    var icon: String
    var iconState: String?
    var iconColorHex: String
    var staticIcon: Bool?
    var stateToken: String
    var fallbackSymbol: SFSymbol?
}

struct WatchIconView: View {
    let model: IconRenderModel
    var settings: AppSettings = .shared
    @ObservedObject private var networkTracker = MainActorNetworkTracker.shared
    @State private var lastResolvedIconURL: URL?
    @State private var lastResolvedConnection: ConnectionInfo?
    @State private var keepLastResolvedIconURLUntil: Date = .distantPast

    private let iconURLGraceSeconds: TimeInterval = 3

    private var iconURL: URL? {
        guard !model.icon.isEmpty, model.icon != "number" else { return nil }
        guard let activeConnection = networkTracker.activeConnection,
              !activeConnection.configuration.url.isEmpty else { return nil }
        return Endpoint.icon(
            rootUrl: activeConnection.configuration.url,
            version: activeConnection.version,
            icon: model.icon,
            state: model.iconState,
            iconType: settings.iconType,
            iconColor: model.iconColorHex,
            staticIcon: model.staticIcon
        )?.url
    }

    /// During a transient connection handover activeConnection can briefly be nil.
    /// Hold the last successfully resolved URL and connection for a short grace period
    /// so icons don't flash blank between reconnects, and retained auth carries over.
    private var displayIconURL: URL? {
        if let url = iconURL { return url }
        guard Date() <= keepLastResolvedIconURLUntil else { return nil }
        return lastResolvedIconURL
    }

    private var displayConnection: ConnectionInfo? {
        if let connection = networkTracker.activeConnection { return connection }
        guard Date() <= keepLastResolvedIconURLUntil else { return nil }
        return lastResolvedConnection
    }

    var body: some View {
        Group {
            if let iconURL = displayIconURL {
                // Only apply color preprocessing for non-iconify icons
                let processorIconColor = iconURL.host == "api.iconify.design" ? nil : model.iconColorHex
                KFImage.url(iconURL)
                    .withOpenHABCredentials(for: displayConnection)
                    .onFailure { error in
                        Logger.rowViews.error("Icon loading failed for icon '\(model.icon, privacy: .public)': \(error.localizedDescription, privacy: .public)")
                        Logger.rowViews.error("Failed URL: \(iconURL.absoluteString, privacy: .public)")
                    }
                    .onFailureView {
                        Rectangle()
                            .foregroundStyle(.background)
                    }
                    .setProcessor(OpenHABImageProcessor(iconColor: processorIconColor))
                    .cacheOriginalImage(false)
                    .loadTransition(.opacity, animation: .easeInOut(duration: 0.25))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .id("\(iconURL.absoluteString)-\(model.stateToken)-\(model.iconColorHex)")
            } else if let fallbackSymbol = model.fallbackSymbol {
                Image(systemSymbol: fallbackSymbol)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 15, height: 15)
                    .foregroundStyle(.primary)
            } else {
                Rectangle()
                    .foregroundStyle(.background)
                    .frame(width: 20, height: 20)
            }
        }
        .onChange(of: iconURL) { _, newURL in
            if let newURL {
                lastResolvedIconURL = newURL
                lastResolvedConnection = networkTracker.activeConnection
                keepLastResolvedIconURLUntil = .distantPast
            } else if lastResolvedIconURL != nil {
                keepLastResolvedIconURLUntil = Date().addingTimeInterval(iconURLGraceSeconds)
            }
        }
    }
}

#Preview {
    let testURL = URL(string: "https://picsum.photos/20")!
    KFImage(testURL)
        .resizable()
        .frame(width: 20, height: 20)

    // Set localTestingURL to your local openHAB server for preview testing
    let localTestingURL = "http://192.168.2.10:8080"

    let endpoint = Endpoint.icon(rootUrl: localTestingURL, version: 4, icon: "switch", state: "2", iconType: .png, iconColor: "blue")
    KFImage(endpoint?.url)
        .setProcessor(OpenHABImageProcessor(iconColor: endpoint?.url?.host == "api.iconify.design" ? nil : "blue"))
        .resizable()
        .frame(width: 20, height: 20)

    let settings = AppSettings(debug: true, openHABRootUrl: localTestingURL)
    let widget = UserData(preview: true).widgets[4]
    WatchIconView(
        model: widget.iconRenderModel(),
        settings: settings
    )

    let endpoint2 = Endpoint.icon(rootUrl: localTestingURL, version: 3, icon: "f7:alarm", state: "", iconType: .svg, iconColor: "yellow")
    KFImage(endpoint2?.url)
        .setProcessor(OpenHABImageProcessor(iconColor: endpoint2?.url?.host == "api.iconify.design" ? nil : "yellow"))
        .resizable()
        .frame(width: 20, height: 20)

    let widget2 = UserData(preview: true).widgets[11]
    WatchIconView(
        model: widget2.iconRenderModel(),
        settings: settings
    )
}
