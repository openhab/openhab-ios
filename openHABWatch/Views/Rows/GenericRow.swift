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
import os.log
import SwiftUI

struct GenericRow: View {
    @ObservedObject var widget: OpenHABWidget
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        HStack {
            IconView(widget: widget, settings: settings)
            TextLabelView(widget: widget)
            Spacer()
            DetailTextLabelView(widget: widget)
            widget.makeView(settings: settings)
        }
    }
}

#Preview {
    let widget = UserData(preview: true).widgets[6]
    GenericRow(widget: widget)
        .environmentObject(AppSettings())
}
