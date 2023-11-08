// Copyright (c) 2010-2023 Contributors to the openHAB project
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
import SwiftUI

struct IconView: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

    var iconURL: URL? {
        Endpoint.icon(
            rootUrl: settings.openHABRootUrl,
            version: 2,
            icon: widget.icon,
            state: widget.item?.state ?? "",
            iconType: .png,
            iconColor: ""
        ).url
    }

    var body: some View {
        let image = iconURL != nil ? KFImage(source: .network(KF.ImageResource(
            downloadURL: iconURL!,
            cacheKey: iconURL!.path + (iconURL!.query ?? "")
        ))) : KFImage(iconURL)
        return image
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
                    .hidden()
            }
            .cancelOnDisappear(true)
            .resizable()
            .scaledToFit()
            .frame(width: 20.0, height: 20.0)
    }
}

struct IconView_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[3]
        return IconView(widget: widget, settings: ObservableOpenHABDataObject(openHABRootUrl: PreviewConstants.remoteURLString))
    }
}
