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
import OpenHABCore
import SwiftUI

struct FrameRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        HStack {
            Text(widget.labelText?.uppercased() ?? "")
                .font(.callout)
                .foregroundColor(.secondary)
                .lineLimit(1)
            Spacer()
        }
        .listRowBackground(Color(UIColor.systemGroupedBackground))
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[6]
    List([widget]) { widget in
        FrameRowView(widget: widget)
    }
    .environmentObject(SitemapPageViewModel())
}
