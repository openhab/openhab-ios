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

import OpenHABCore
import SwiftUI

struct GenericRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        HStack {
            IconView(widget: widget)
                .frame(width: 24, height: 24)

            Text(widget.labelText ?? "")
            Spacer()
            if let value = widget.labelValue {
                Text(value)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[6]
    List([widget]) { widget in
        GenericRowView(widget: widget)
    }
}
