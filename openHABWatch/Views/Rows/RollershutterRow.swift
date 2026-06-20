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

struct RollershutterRow: View {
    let widget: OpenHABWidget
    @Environment(AppSettings.self) var settings
    @State private var commandSender = WidgetCommandDispatcher()

    var body: some View {
        VStack(spacing: -5) {
            HStack {
                WatchIconView(model: widget.iconRenderModel(), settings: settings)
                WatchLabelText(text: widget.labelText, labelColor: widget.labelcolor)
                Spacer()
                DetailTextLabelView(text: widget.labelValue, valueColor: widget.valuecolor)
            }
            HStack {
                Spacer()
                IconWithAction(systemSymbol: .arrowtriangleDownCircleFill, accessibilityLabel: "Move down") {
                    commandSender.send("DOWN", for: widget, policy: .immediate)
                }
                Spacer()
                IconWithAction(systemSymbol: .stopCircleFill, accessibilityLabel: "Stop") {
                    commandSender.send("STOP", for: widget, policy: .immediate)
                }
                Spacer()
                IconWithAction(systemSymbol: .arrowtriangleUpCircleFill, accessibilityLabel: "Move up") {
                    commandSender.send("UP", for: widget, policy: .immediate)
                }
                Spacer()
            }
            .frame(height: 50)
        }
        .accessibilityLabel(widget.labelText)
    }
}

#Preview {
    let widget = PreviewWidgetFactory.rollershutter(label: "Blinds", state: "STOP")
    PreviewNavigationContainer {
        RollershutterRow(widget: widget)
    }
}
