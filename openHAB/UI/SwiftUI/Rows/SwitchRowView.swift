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
    SwitchRowContent(
        input: input,
        interactionState: viewModel.rowInteractionState(for: input.itemName)
    ) { command in
        guard let itemName = input.itemName else { return }
        viewModel.sendCommand(itemname: itemName, command: command)
    }
}

private struct SwitchRowContent: View {
    let input: ToggleRowInput
    let interactionState: RowInteractionState
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
                    // Revert is driven by interactionState transitions (see onChange below),
                    // not a fixed tap-time timer. Cancel any prior revert from an earlier command.
                    revertTask?.cancel()
                    revertTask = nil
                }
            ))
            .padding(2)
            .labelsHidden()
            .disabled(input.readOnly)
        }
        .contentShape(Rectangle())
        .onChange(of: displayState.effectiveState) { _ in
            // Server confirmed the new state — clear optimistic override.
            revertTask?.cancel()
            revertTask = nil
            localIsOn = nil
        }
        .onChange(of: interactionState) { newState in
            switch newState {
            case .idle:
                // HTTP command completed. Wait a short window for SSE/long-poll to arrive
                // before clearing the optimistic state. Items with autoupdate=false never
                // trigger the effectiveState change above, so the timer is their only revert.
                guard localIsOn != nil else { return }
                revertTask?.cancel()
                revertTask = Task { @MainActor in
                    do { try await Task.sleep(for: .seconds(1.5)) } catch { return }
                    localIsOn = nil
                }
            case .failed:
                revertTask?.cancel()
                revertTask = nil
                localIsOn = nil
            case .sending, .queued, .offline:
                break
            }
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
