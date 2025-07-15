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

import CommonUI
import OpenHABCore
import os.log
import SFSafeSymbols
import SwiftUI

struct RollershutterRowView: View {
    @ObservedObject var widget: OpenHABWidget

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetRollershutterView")

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if IconView.shouldShowIcon(for: widget) {
                    IconView(widget: widget)
                        .frame(width: 24, height: 24)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(widget.labelText ?? widget.label)
                        .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
                }

                Spacer()

                Button {
                    logger.info("up button pressed")
                    widget.sendCommand("UP")
                } label: {
                    Image(systemSymbol: .chevronUp)
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

                Button {
                    logger.info("stop button pressed")
                    widget.sendCommand("STOP")
                } label: {
                    Image(systemSymbol: .stop)
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

                Button {
                    logger.info("down button pressed")
                    widget.sendCommand("DOWN")
                } label: {
                    Image(systemSymbol: .chevronDown)
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[5]
    VStack {
        RollershutterRowView(widget: widget)
        Spacer()
    }
}
