// Copyright (c) 2010-2019 Contributors to the openHAB project
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
import os.log
import SwiftUI

struct SwitchRow: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var dataObject: OpenHABDataObject

    var iconUrl: URL? {
        return Endpoint.icon(rootUrl: dataObject.openHABRootUrl,
                             version: 2,
                             icon: widget.icon,
                             value: widget.item?.state ?? "",
                             iconType: .png).url
    }

    var body: some View {
        return Toggle(isOn: $widget.stateBinding) {
            HStack {
                KFImage(iconUrl)
                    .onSuccess { retrieveImageResult in
                        os_log("success: %{PUBLIC}s", log: .notifications, type: .debug, retrieveImageResult)
                    }
                    .onFailure { kingfisherError in
                        os_log("failure: %{PUBLIC}s", log: .notifications, type: .debug, kingfisherError)
                    }
                    .placeholder {
                        Image(systemName: "arrow.2.circlepath.circle")
                            .font(.callout)
                            .opacity(0.3)
                    }
                    .cancelOnDisappear(true)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 25.0, height: 25.0)
                Text(widget.label)
                    .font(.callout)
                Spacer()
                Text("llls")
                    .font(.caption)
            }
        }
        .cornerRadius(10)
    }
}

struct SwitchRow_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().items[0]
        return SwitchRow(widget: widget)
            .previewLayout(.fixed(width: 300, height: 70))
            .environmentObject(OpenHABDataObject())
    }
}
