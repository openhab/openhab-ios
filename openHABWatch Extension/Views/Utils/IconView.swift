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

// swiftlint:disable file_types_order
struct IconView: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

    var iconURL: URL? {
        Endpoint.icon(rootUrl: settings.openHABRootUrl,
                      version: 2,
                      icon: widget.icon,
                      value: widget.item?.state ?? "",
                      iconType: .png).url
    }

    var body: some View {
        ImageRow(URL: iconURL)
            .frame(width: 20.0, height: 20.0)
    }
}

struct IconView_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[3]
        return IconView(widget: widget, settings: ObservableOpenHABDataObject(openHABRootUrl: PreviewConstants.remoteURLString))
    }
}
