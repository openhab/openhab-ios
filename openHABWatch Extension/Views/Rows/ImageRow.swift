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
struct ImageRow: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    var url: URL?
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

    var body: some View {
        KFImage(url)
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
        let widget = UserData().widgets[4]
        return ImageRow(widget: widget)
    }
}
