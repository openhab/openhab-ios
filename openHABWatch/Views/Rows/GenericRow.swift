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

struct GenericRow: View {
    let widget: OpenHABWidget
    let settings = AppSettings.shared

    var body: some View {
        HStack {
            WatchIconView(model: widget.iconRenderModel(), settings: settings)
            WatchLabelText(text: widget.labelText, labelColor: widget.labelcolor)
            Spacer()
            DetailTextLabelView(text: widget.labelValue, valueColor: widget.valuecolor)
            widget.makeView(settings: settings)
        }
        .accessibilityLabel(widget.labelText)
    }
}

#Preview {
    let widget = PreviewWidgetFactory.generic(label: "Unsupported Widget", valueText: "N/A")
    PreviewNavigationContainer {
        GenericRow(widget: widget)
    }
}
