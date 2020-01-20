//
//  IconView.swift
//  openHABWatchSwift Extension
//
//  Created by Tim Müller-Seydlitz on 20.01.20.
//  Copyright © 2020 openHAB e.V. All rights reserved.
//

import Kingfisher
import OpenHABCoreWatch
import os.log
import SwiftUI

// swiftlint:disable file_types_order
struct IconView: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

    var iconUrl: URL? {
        Endpoint.icon(rootUrl: settings.openHABRootUrl,
                      version: 2,
                      icon: widget.icon,
                      value: widget.item?.state ?? "",
                      iconType: .png).url
    }
    var body: some View {
        KFImage(iconUrl)
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
        .frame(width: 20.0, height: 20.0)
    }
}

struct IconView_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[3]
        return IconView(widget: widget, settings: ObservableOpenHABDataObject(openHABRootUrl: PreviewConstants.remoteURLString))
    }
}
