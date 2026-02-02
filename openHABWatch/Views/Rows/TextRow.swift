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
import SFSafeSymbols
import SwiftUI

struct TextRow: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        HStack {
            IconView(widget: widget, settings: settings)
            TextLabelView(widget: widget)
            Spacer()
            DetailTextLabelView(widget: widget)
            if widget.linkedPage != nil {
                Image(systemSymbol: .chevronRight)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }
}

#Preview {
    let widget = UserData(preview: true).widgets[3]
    TextRow(widget: widget)
        .environmentObject(AppSettings())
}
