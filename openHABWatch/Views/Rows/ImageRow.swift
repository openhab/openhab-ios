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

struct ImageRow: View {
    @State var url: URL?
    @EnvironmentObject var settings: ObservableOpenHABDataObject

    var body: some View {
        WebImage(
            url: url,
            options: settings.ignoreSSL ? [.allowInvalidSSLCertificates] : [],
            context: [
                .imageThumbnailPixelSize: CGSize.zero
            ]
        ) { image in
            image.resizable()
                
        } placeholder: {
            Image(systemSymbol: .arrowTriangle2CirclepathCircle)
                .font(.callout)
                .opacity(0.3)
        }
        .cancelOnDisappear(true)
        .transition(.fade(duration: 0.3))
        .scaledToFit()
    }
}

#Preview {
    let iconUrl = Endpoint.icon(
        rootUrl: PreviewConstants.remoteURLString,
        version: 2,
        icon: "Switch",
        state: "ON",
        iconType: .svg,
        iconColor: ""
    ).url
    return ImageRow(url: iconUrl)
        .environmentObject(ObservableOpenHABDataObject())
}
