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
import SFSafeSymbols
import SwiftUI

@MainActor
private func sendSetpointValue(_ value: Double, for input: SetpointRowInput, viewModel: SitemapPageViewModel) {
    guard let itemName = input.itemName else { return }
    let state = NumberState(
        value: value,
        unit: input.unit,
        format: input.numberPattern
    )
    viewModel.sendToUpdate(itemname: itemName, state: state)
}

private struct SetpointRowContent: View {
    let input: SetpointRowInput
    @Binding var triggerFeedback: Bool
    let onSendValue: (Double) -> Void

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetSetpointView")
    private let setpointService = SetPointService()

    var body: some View {
        let displayState = input.displayState
        let currentValue = currentValue(displayState: displayState)
        RowViewWithIcon(input: input) {
            if !displayState.labelText.isEmpty {
                let labelText = displayState.labelText
                Text(labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Button {
                    triggerFeedback.toggle()
                    decreaseValue(displayState: displayState)
                } label: {
                    Image(systemSymbol: .minusCircle)
                        .font(.title2)
                        .foregroundStyle(currentValue <= displayState.minValue ? Color(.systemGray2) : Color(UIColor.systemBlue))
                }
                .buttonStyle(.plain)
                .disabled(currentValue <= displayState.minValue)
                .sensoryHeavyFeedbackIfAvailable(trigger: triggerFeedback)
                .disabled(input.readOnly)

                Text(formattedValue(displayState: displayState))
                    .ohTextToken(.rowValue)
                    .monospacedDigit()
                    .foregroundStyle(input.valueColor.isEmpty ? .secondary : Color(fromString: input.valueColor))

                Button {
                    triggerFeedback.toggle()
                    increaseValue(displayState: displayState)
                } label: {
                    Image(systemSymbol: .plusCircle)
                        .font(.title2)
                        .foregroundStyle(currentValue >= displayState.maxValue ? Color(.systemGray2) : Color(UIColor.systemBlue))
                }
                .buttonStyle(.plain)
                .disabled(currentValue >= displayState.maxValue)
                .sensoryHeavyFeedbackIfAvailable(trigger: triggerFeedback)
                .disabled(input.readOnly)
            }
            .padding(.trailing, -2)
        }
    }

    private func decreaseValue(displayState: WidgetDisplayState) {
        handleUpDown(isDecreasing: true, displayState: displayState)
    }

    private func increaseValue(displayState: WidgetDisplayState) {
        handleUpDown(isDecreasing: false, displayState: displayState)
    }

    private func handleUpDown(isDecreasing: Bool, displayState: WidgetDisplayState) {
        let currentValue = input.serverValue

        let limitedNewValue = setpointService.calculateNewValue(
            currentValue: currentValue,
            step: displayState.step,
            minValue: displayState.minValue,
            maxValue: displayState.maxValue,
            isDecreasing: isDecreasing
        )

        guard limitedNewValue != currentValue else {
            // nothing to update, skip sending value
            return
        }

        logger.info("Setpoint \(isDecreasing ? "decreased" : "increased") to \(String(limitedNewValue))")
        onSendValue(limitedNewValue)
    }

    private func currentValue(displayState: WidgetDisplayState) -> Double {
        input.serverValue
    }

    private func formattedValue(displayState: WidgetDisplayState) -> String {
        SetpointDisplayFormatter.text(
            labelValue: displayState.labelValue,
            localValue: nil,
            serverValue: currentValue(displayState: displayState),
            minValue: displayState.minValue,
            step: displayState.step,
            unit: input.unit,
            numberPattern: input.numberPattern,
            locale: Locale.current
        )
    }
}

struct SetpointRowView: View {
    let input: SetpointRowInput

    @EnvironmentObject var viewModel: SitemapPageViewModel
    @State private var triggerFeedback = false

    var body: some View {
        SetpointRowContent(
            input: input,
            triggerFeedback: $triggerFeedback
        ) { value in
            sendSetpointValue(value, for: input, viewModel: viewModel)
        }
    }
}

#if DEBUG
#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[3]
    VStack {
        SetpointRowView(input: SetpointRowInput.from(widget: widget))
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
#endif
