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

    private let logger = Logger(subsystem: "org.openhab", category: "WatchIconView")

    var iconURL: URL? {
        guard !widget.icon.isEmpty,
              let activeConnection = networkTracker.activeConnection,
              !activeConnection.configuration.url.isEmpty else {
            return nil
        }

        var iconColor = widget.iconColor
        if iconColor.isEmpty {
            iconColor = "white"
        }
        return Endpoint.icon(
            rootUrl: activeConnection.configuration.url,
            version: activeConnection.version,
            icon: widget.icon,
            state: widget.iconState(),
            iconType: settings.iconType,
            iconColor: iconColor
        ).url
    }

    var body: some View {
        Group {
            if let iconURL, !imageLoadingFailed {
                KFImage(iconURL)
                    .placeholder {
                        Image(systemSymbol: .circle)
                            .frame(width: 20, height: 20)
                    }
                    .onFailure { error in
                        logger.error("Icon loading failed for widget \(widget.label): \(error.localizedDescription)")
                        handleLoadingFailure()
                    }
                    .onSuccess { _ in
                        imageLoadingFailed = false
                        retryCount = 0
                    }
                    .setProcessor(OpenHABImageProcessor())
                    .fade(duration: 0.25)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .id(iconURL.absoluteString)
            } else {
                // Show fallback when no icon or failed to load
                Image(systemSymbol: .circle)
                    .frame(width: 20, height: 20)
                    .opacity(0.3)
            }
        }
        .onChange(of: widget.icon) { _ in
            resetLoadingState()
        }
        .onChange(of: widget.iconState()) { _ in
            resetLoadingState()
        }
        .onChange(of: networkTracker.activeConnection) { _ in
            resetLoadingState()
        }
    }

    private func handleLoadingFailure() {
        if retryCount < maxRetries {
            retryCount += 1
            logger.info("Retrying icon load for widget \(widget.label), attempt \(retryCount)/\(maxRetries)")

            DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay * Double(retryCount)) {
                imageLoadingFailed = false
            }
        } else {
            logger.warning("Max retries reached for widget \(widget.label), giving up")
            imageLoadingFailed = true
        }
    }

    private func resetLoadingState() {
        imageLoadingFailed = false
        retryCount = 0
    }
}

#Preview {
    let widget2 = UserData(preview: true).widgets[4]
    IconView(
        widget: widget2,
        settings: AppSettings()
    )
}
