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

struct GenericRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        HStack {
            IconView(widget: widget)
                .frame(width: 32, height: 32)

            Text(widget.labelText ?? "")
                .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))

            Spacer()

            if let value = widget.labelValue {
                Text(value)
                    .foregroundStyle(widget.valuecolor.isEmpty ? .secondary : Color(fromString: widget.valuecolor))
            }
        }
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[6]
    List([widget]) { widget in
        GenericRowView(widget: widget)
    }
    .environmentObject(SitemapPageViewModel())
}
