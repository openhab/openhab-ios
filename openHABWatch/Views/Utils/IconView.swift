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

import OpenHABCore
import os.log
import SDWebImageSwiftUI
import SwiftUI

struct IconView: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

    var iconURL: URL? {
        var iconColor = widget.iconColor
        if iconColor.isEmpty {
            iconColor = "white"
        }
        return Endpoint.icon(
            rootUrl: settings.openHABRootUrl,
            version: settings.openHABVersion,
            icon: widget.icon,
            state: widget.item?.state ?? "",
            iconType: settings.iconType,
            iconColor: iconColor
        ).url
    }

    var body: some View {
        // Inspired by https://anoop4real.medium.com/display-svg-in-swiftui-ios-watchos-260120557e3a
        WebImage(
            url: iconURL,
            options: settings.ignoreSSL ? [.allowInvalidSSLCertificates] : [],
            context: [.imageThumbnailPixelSize: CGSize.zero]
        )
        .cancelOnDisappear(true)
        .resizable()
        .scaledToFit()
        .frame(width: 20.0, height: 20.0)
    }
}

#Preview {
    let widget = UserData().widgets[3]
    return IconView(widget: widget, settings: ObservableOpenHABDataObject(openHABRootUrl: PreviewConstants.remoteURLString))
}
