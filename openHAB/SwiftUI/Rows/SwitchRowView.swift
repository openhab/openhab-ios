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

@MainActor
private func makeSwitchRowContent(input: BasicWidgetRowInput,
                                  iconWidget: OpenHABWidget,
                                  commandWidget: OpenHABWidget,
                                  viewModel: SitemapPageViewModel) -> SwitchRowContent {
    SwitchRowContent(
        input: input,
        iconWidget: iconWidget
    ) { command in
        viewModel.sendCommand(command, for: commandWidget)
    }
}

private struct SwitchRowContent: View {
    let input: BasicWidgetRowInput
    let iconWidget: OpenHABWidget
    let onSendCommand: (String) -> Void
    @State private var localIsOn: Bool?

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetSwitchView")

    var body: some View {
        let displayState = input.displayState
        HStack {
            IconView(widget: iconWidget)
                .frame(width: 32, height: 32)

            if !displayState.labelText.isEmpty {
                let labelText = displayState.labelText
                Text(labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))
            }

            Spacer()

            if let labelValue = displayState.labelValue, !labelValue.isEmpty {
                Text(labelValue)
                    .ohTextToken(.rowValueCompact)
                    .foregroundStyle(input.valueColor.isEmpty ? .secondary : Color(fromString: input.valueColor))
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
                    onSendCommand(newState)
                }
            ))
            .labelsHidden()
            .disabled(input.readOnly)
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

struct SwitchRowInputView: View {
    let rowID: RowID
    let input: BasicWidgetRowInput

    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        if let widget = viewModel.widget(for: rowID) {
            makeSwitchRowContent(
                input: input,
                iconWidget: widget,
                commandWidget: widget,
                viewModel: viewModel
            )
        } else {
            EmptyView()
        }
    }
}

struct SwitchRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        makeSwitchRowContent(
            input: BasicWidgetRowInput.from(widget: widget),
            iconWidget: widget,
            commandWidget: widget,
            viewModel: viewModel
        )
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
