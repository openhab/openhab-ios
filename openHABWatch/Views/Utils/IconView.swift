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
    let logger = Logger(subsystem: "org.openhab", category: "IconView")

    var iconURL: URL? {
        var iconColor = widget.iconColor
        if iconColor.isEmpty {
            iconColor = "#FFFFFF"
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
            KFImage(iconURL)
                .onFailure { _ in
                    logger.debug("Failed to load image : \(iconURL.absoluteString)")
                }
                .onSuccess { _ in
                    logger.debug("Successfully loaded image: \(iconURL.absoluteString)")
                }
                .setProcessor(OpenHABImageProcessor())
                .fade(duration: 0.25)
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

    let endpoint = Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 4, icon: "switch", state: "2", iconType: .png, iconColor: "blue")
    KFImage(endpoint?.url)
        .setProcessor(OpenHABImageProcessor())
        .resizable()
        .frame(width: 20, height: 20)

    let settings = AppSettings(debug: true, openHABRootUrl: "http://192.168.2.10:8080")
    let widget = UserData(preview: true).widgets[4]
    IconView(
        widget: widget,
        settings: settings
    )

    let endpoint2 = Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 3, icon: "f7:alarm", state: "", iconType: .svg, iconColor: "#FFFFFF")
//    Text(endpoint2?.url?.absoluteString ?? "nil")
//        .font(.system(size: 8))
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
