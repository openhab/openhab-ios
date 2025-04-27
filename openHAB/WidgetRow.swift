// Copyright (c) 2010-2025 Contributors to the openHAB project
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

struct WidgetRow: View {
    let widget: OpenHABWidget

    var body: some View {
        HStack {
//            if let iconUrl = widget.iconUrl {
//                KFImage(iconUrl)
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 30, height: 30)
//            }
            VStack(alignment: .leading) {
                Text(widget.labelText ?? "")
                    .font(.headline)
                if let value = widget.labelValue, !value.isEmpty {
                    Text(value)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
