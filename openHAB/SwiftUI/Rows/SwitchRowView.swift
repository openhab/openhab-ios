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
import os.log
import SwiftUI

struct SwitchRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var viewModel: SitemapPageViewModel
    @State private var localIsOn: Bool?

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
        localIsOn ?? effectiveState.parseAsBool()
    }

    var body: some View {
        HStack {
            IconView(widget: widget)
                .frame(width: 24, height: 24)

            if let labelText = widget.labelText, !labelText.isEmpty {
                Text(labelText)
                    .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
            }

            Spacer()

            if let labelValue = widget.labelValue, !labelValue.isEmpty {
                Text(labelValue)
                    .font(.caption)
                    .foregroundStyle(widget.valuecolor.isEmpty ? .secondary : Color(fromString: widget.valuecolor))
            }

            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    localIsOn = newValue
                    let newState = newValue ? "ON" : "OFF"
                    if newValue {
                        logger.info("\("Switch to ON")")
                    } else {
                        logger.info("\("Switch to OFF")")
                    }
                    viewModel.sendCommand(widget.item, commandToSend: newState)
                }
            ))
            .labelsHidden()
            .disabled(widget.readOnly ?? false)
        }
        .contentShape(Rectangle())
        .onChange(of: effectiveState) { _ in
            // Sync local state when server state changes
            localIsOn = nil
        }
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[2]
    VStack {
        SwitchRowView(widget: widget)
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
