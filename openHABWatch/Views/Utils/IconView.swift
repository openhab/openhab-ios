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

struct IconView: View {
    @ObservedObject var widget: OpenHABWidget
    @ObservedObject var settings = AppSettings.shared

    var iconColor: String {
        let logicColor = !(widget.iconColor.isEmpty) ? UIColor(fromString: widget.iconColor) : .ohBlack
        return logicColor.semanticColorToHex() ?? "#FFFFFF"
    }

    var iconURL: URL? {
        // Skip loading number icons as they don't exist/aren't useful
        if widget.icon == "number" {
            return nil
        }

        return Endpoint.icon(
            rootUrl: settings.openHABRootUrl,
            version: settings.openHABVersion,
            icon: widget.icon,
            state: widget.iconState(),
            iconType: settings.iconType,
            iconColor: iconColor,
            staticIcon: widget.staticIcon
        )?.url
    }

    var body: some View {
        if let iconURL {
            // Only apply color preprocessing for non-iconify icons
            let processorIconColor = iconURL.host == "api.iconify.design" ? nil : iconColor
            KFImage.url(iconURL)
                .onFailure { _ in
                    Logger.rowViews.debug("Failed to load image : \(iconURL.absoluteString)")
                }
                .onFailureView {
                    Rectangle()
                        .foregroundStyle(.background)
                }
                .setProcessor(OpenHABImageProcessor(iconColor: processorIconColor))
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
    IconView(
        widget: widget,
        settings: settings
    )

    let endpoint2 = Endpoint.icon(rootUrl: localTestingURL, version: 3, icon: "f7:alarm", state: "", iconType: .svg, iconColor: "yellow")
    KFImage(endpoint2?.url)
        .setProcessor(OpenHABImageProcessor(iconColor: endpoint2?.url?.host == "api.iconify.design" ? nil : "yellow"))
        .resizable()
        .frame(width: 20, height: 20)

    let widget2 = UserData(preview: true).widgets[11]
    IconView(
        widget: widget2,
        settings: settings
    )
}
