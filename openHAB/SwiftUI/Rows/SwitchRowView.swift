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
import SwiftUI

struct SwitchRowView: View {
    @ObservedObject var widget: OpenHABWidget

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetSwitchView")

    private var effectiveState: String {
        var state = widget.state
        // If state is nil or empty using the item state (OH 1.x compatibility)
        if state.isEmpty {
            state = widget.item?.state ?? ""
        }
        return state
    }

    private var isOn: Bool {
        effectiveState.parseAsBool()
    }

    var body: some View {
        HStack {
            if IconView.shouldShowIcon(for: widget) {
                IconView(widget: widget)
                    .frame(width: 24, height: 24)
            }

            Text(widget.labelText ?? widget.label)
                .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
            Spacer()

            if let labelValue = widget.labelValue, !labelValue.isEmpty {
                Text(labelValue)
                    .font(.caption)
                    .foregroundColor(widget.valuecolor.isEmpty ? .secondary : Color(fromString: widget.valuecolor))
            }

            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    let newState = newValue ? "ON" : "OFF"
                    if newValue {
                        logger.info("Switch to ON")
                    } else {
                        logger.info("Switch to OFF")
                    }
                    widget.sendCommand(newState)
                }
            ))
            .labelsHidden()
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[2]
    VStack {
        SwitchRowView(widget: widget)
        Spacer()
    }
}
