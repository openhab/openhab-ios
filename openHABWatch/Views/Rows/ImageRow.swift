// Copyright (c) 2010-2026 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import CommonUI
import Kingfisher
import OpenHABCore
import os.log
import SwiftUI

struct ImageRow: View {
    @State var url: URL?
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        KFImage(url)
            .placeholder {
                ProgressView()
                    .frame(width: 20, height: 20)
            }
            .fade(duration: 0.25)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .id(url?.absoluteString ?? "")
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
    )?.url
    ImageRow(url: iconUrl)
        .environmentObject(AppSettings())
}
