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
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

    var body: some View {
        WebImage(
            url: url,
            options: settings.ignoreSSL ? [.allowInvalidSSLCertificates] : [],
            context: [
                .imageThumbnailPixelSize: CGSize.zero
            ]
        )
        .onFailure { error in
            os_log("Failure loading icon: %{PUBLIC}s", log: .notifications, type: .debug, error.localizedDescription)
        }
        .placeholder {
            Image(systemName: "arrow.2.circlepath.circle")
                .font(.callout)
                .opacity(0.3)
        }
        .cancelOnDisappear(true)
        .resizable()
        .scaledToFit()
    }
}

struct ImageRow_Previews: PreviewProvider {
    static var previews: some View {
        let iconUrl = Endpoint.icon(
            rootUrl: PreviewConstants.remoteURLString,
            version: 2,
            icon: "Switch",
            state: "ON",
            iconType: .png,
            iconColor: ""
        ).url
        // let widget = UserData().widgets[8]
        return ImageRow(url: iconUrl)
    }
}
