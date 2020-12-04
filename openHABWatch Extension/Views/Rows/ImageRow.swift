// Copyright (c) 2010-2020 Contributors to the openHAB project
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
import OpenHABCoreWatch
import os.log
import SwiftUI

struct ImageRow: View {
    @State var URL: URL?

    var body: some View {
        KFImage(URL)
            .onSuccess { retrieveImageResult in
                os_log("Success loading icon: %{PUBLIC}s", log: .notifications, type: .debug, "\(retrieveImageResult)")
            }
            .onFailure { kingfisherError in
                os_log("Failure loading icon: %{PUBLIC}s", log: .notifications, type: .debug, kingfisherError.localizedDescription)
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
        let iconURL = Endpoint.icon(
            rootUrl: PreviewConstants.remoteURLString,
            version: 2,
            icon: "Switch",
            state: "ON",
            iconType: .png
        ).url
        // let widget = UserData().widgets[8]
        return ImageRow(URL: iconURL)
    }
}
