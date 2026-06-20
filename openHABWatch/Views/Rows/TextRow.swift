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
    let widget: OpenHABWidget
    @Environment(AppSettings.self) var settings
    let hasLinkedPage: Bool

    var body: some View {
        HStack {
            WatchIconView(model: widget.iconRenderModel(), settings: settings)
            WatchLabelText(text: widget.labelText, labelColor: widget.labelcolor)
            Spacer()
            DetailTextLabelView(text: widget.labelValue, valueColor: widget.valuecolor)
            if hasLinkedPage {
                Image(systemSymbol: .chevronRight)
                    .foregroundStyle(.secondary)
                    .watchTextStyle(.control)
            }
        }
    }
}

#Preview {
    let widget = PreviewWidgetFactory.text(label: "Energy Usage", valueText: "450 W")
    PreviewNavigationContainer {
        TextRow(widget: widget, hasLinkedPage: false)
    }
}
