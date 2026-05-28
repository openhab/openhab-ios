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
private func makeSwitchRowContent(input: ToggleRowInput,
                                  viewModel: SitemapPageViewModel) -> SwitchRowContent {
    SwitchRowContent(input: input) { command in
        guard let itemName = input.itemName else { return }
        viewModel.sendCommand(itemname: itemName, command: command)
    }
}

private struct SwitchRowContent: View {
    let input: ToggleRowInput
    let onSendCommand: (String) -> Void
    @State private var localIsOn: Bool?
    @State private var revertTask: Task<Void, Never>?

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetSwitchView")

    var body: some View {
        let displayState = input.displayState
        RowViewWithIcon(input: input) {
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
                    logger.info("Switch to \(newState, privacy: .public)")
                    onSendCommand(newState)
                    // If the thing rejects the command (autoupdate=false), the server sends back
                    // the same state so onChange never fires — revert optimistic state after 1s.
                    revertTask?.cancel()
                    revertTask = Task { @MainActor in
                        do { try await Task.sleep(for: .seconds(1)) } catch { return }
                        localIsOn = nil
                    }
                }
            ))
            .padding(2)
            .labelsHidden()
            .disabled(input.readOnly)
        }
        .contentShape(Rectangle())
        .onChange(of: displayState.effectiveState) { _ in
            revertTask?.cancel()
            revertTask = nil
            localIsOn = nil
        }
    }

    private func isOn(displayState: WidgetDisplayState) -> Bool {
        localIsOn ?? displayState.isOn
    }
}

struct SwitchRowView: View {
    let input: ToggleRowInput

    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        makeSwitchRowContent(input: input, viewModel: viewModel)
    }
}

#if DEBUG
#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[2]
    VStack {
        SwitchRowView(input: ToggleRowInput.from(widget: widget))
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
#endif
