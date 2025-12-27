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
import SFSafeSymbols
import SwiftUI

struct IconView: View {
    @ObservedObject var widget: OpenHABWidget
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject private var networkTracker = MainActorNetworkTracker.shared

    @State private var imageLoadingFailed = false
    @State private var retryCount = 0
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 1.0

    var iconURL: URL? {
        guard !widget.icon.isEmpty,
              let activeConnection = networkTracker.activeConnection,
              !activeConnection.configuration.url.isEmpty else { return nil }
        // Skip loading number icons as they don't exist/aren't useful
        if widget.icon == "number" {
            return nil
        }

        var iconColor = widget.iconColor
        if iconColor.isEmpty {
            iconColor = "#FFFFFF"
        }
        return Endpoint.icon(
            rootUrl: activeConnection.configuration.url,
            version: activeConnection.version,
            icon: widget.icon,
            state: widget.iconState(),
            iconType: settings.iconType,
            iconColor: iconColor,
            staticIcon: widget.staticIcon
        )?.url
    }

    var body: some View {
        Group {
            if let iconURL {
                KFImage.url(iconURL)
                    .onFailure { _ in
                        Logger.rowViews.debug("Failed to load image : \(iconURL.absoluteString)")
                    }
                    .onFailureView {
                        Rectangle()
                            .foregroundStyle(.background)
                    }
                    .setProcessor(OpenHABImageProcessor())
                    .loadTransition(.opacity, animation: .easeInOut(duration: 0.25))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .id(iconURL.absoluteString)
            } else {
                Rectangle()
                    .foregroundStyle(.background)
                    .frame(width: 20, height: 20)
            }
        }
        .onChange(of: widget.icon) {
            resetLoadingState()
        }
        .onChange(of: widget.iconState()) {
            resetLoadingState()
        }
        .onChange(of: networkTracker.activeConnection) {
            resetLoadingState()
        }
    }

    private func handleLoadingFailure() {
        if retryCount < maxRetries {
            retryCount += 1
            Logger.rowViews.info("Retrying icon load for widget \(widget.label), attempt \(retryCount)/\(maxRetries)")

            DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay * Double(retryCount)) {
                imageLoadingFailed = false
            }
        } else {
            Logger.rowViews.warning("Max retries reached for widget \(widget.label), giving up")
            imageLoadingFailed = true
        }
    }

    private func resetLoadingState() {
        imageLoadingFailed = false
        retryCount = 0
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
        .setProcessor(OpenHABImageProcessor())
        .resizable()
        .frame(width: 20, height: 20)

    let settings = AppSettings(debug: true, openHABRootUrl: localTestingURL)
    let widget = UserData(preview: true).widgets[4]
    IconView(
        widget: widget,
        settings: settings
    )

    let endpoint2 = Endpoint.icon(rootUrl: localTestingURL, version: 3, icon: "f7:alarm", state: "", iconType: .svg, iconColor: "yellow")
    KFImage(endpoint2?.url)
        .setProcessor(OpenHABImageProcessor())
        .resizable()
        .frame(width: 20, height: 20)

    let widget2 = UserData(preview: true).widgets[11]
    IconView(
        widget: widget2,
        settings: settings
    )
}
