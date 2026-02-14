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

    var body: some View {
        let displayState = widget.displayState
        HStack {
            IconView(widget: widget)
                .frame(width: 32, height: 32)

            if !displayState.labelText.isEmpty {
                let labelText = displayState.labelText
                Text(labelText)
                    .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
                    .lineLimit(1)
            }

            Spacer()

            if let labelValue = displayState.labelValue, !labelValue.isEmpty {
                Text(labelValue)
                    .font(.caption)
                    .foregroundStyle(widget.valuecolor.isEmpty ? .secondary : Color(fromString: widget.valuecolor))
                    .lineLimit(1)
            }

            Toggle("", isOn: Binding(
                get: { isOn(displayState: displayState) },
                set: { newValue in
                    localIsOn = newValue
                    let newState = newValue ? "ON" : "OFF"
                    if newValue {
                        logger.info("\("Switch to ON")")
                    } else {
                        logger.info("\("Switch to OFF")")
                    }
                    viewModel.sendCommand(newState, for: widget)
                }
            ))
            .labelsHidden()
            .disabled(widget.readOnly ?? false)
        }
        .contentShape(Rectangle())
        .onChange(of: displayState.effectiveState) { _ in
            // Sync local state when server state changes
            localIsOn = nil
        }
    }

    private func isOn(displayState: WidgetDisplayState) -> Bool {
        localIsOn ?? displayState.isOn
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
