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

    var iconURL: URL? {
        var iconColor = widget.iconColor
        if iconColor.isEmpty {
            iconColor = "white"
        }
        return Endpoint.icon(
            rootUrl: settings.openHABRootUrl,
            version: settings.openHABVersion,
            icon: widget.icon,
            state: widget.iconState(),
            iconType: settings.iconType,
            iconColor: iconColor
        ).url
    }

    var body: some View {
        KFImage(iconURL)
            .placeholder {
                Image(systemSymbol: .circle)
                    .frame(width: 20, height: 20)
            }
            .setProcessor(OpenHABImageProcessor())
            .fade(duration: 0.25)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 20)
            .id(iconURL?.absoluteString ?? "")
    }
}

#Preview {
    let widget2 = UserData(preview: true).widgets[4]
    IconView(
        widget: widget2,
        settings: AppSettings()
    )
}
