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

struct SetpointRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var viewModel: SitemapPageViewModel
    @State private var triggerFeedback = false

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetSetpointView")
    private let setpointService = SetPointService()

    var body: some View {
        let displayState = widget.displayState
        let currentValue = currentValue(displayState: displayState)
        HStack {
            IconView(widget: widget)
                .frame(width: 32, height: 32)

            if !displayState.labelText.isEmpty {
                let labelText = displayState.labelText
                Text(labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    triggerFeedback.toggle()
                    decreaseValue(displayState: displayState)
                } label: {
                    Image(systemSymbol: .chevronDown)
                        .font(.body)
                        .foregroundStyle(currentValue <= displayState.minValue ? Color(.systemGray2) : Color(UIColor.systemBlue))
                }
                .buttonStyle(.plain)
                .disabled(currentValue <= displayState.minValue)
                .sensoryHeavyFeedbackIfAvailable(trigger: triggerFeedback)
                .disabled(widget.readOnly ?? false)

                Text(formattedValue(displayState: displayState))
                    .ohTextToken(.rowValue)
                    .monospacedDigit()
                    .foregroundStyle(widget.valuecolor.isEmpty ? .secondary : Color(fromString: widget.valuecolor))

                Button {
                    triggerFeedback.toggle()
                    increaseValue(displayState: displayState)
                } label: {
                    Image(systemSymbol: .chevronUp)
                        .font(.body)
                        .foregroundStyle(currentValue >= displayState.maxValue ? Color(.systemGray2) : Color(UIColor.systemBlue))
                }
                .buttonStyle(.plain)
                .disabled(currentValue >= displayState.maxValue)
                .sensoryHeavyFeedbackIfAvailable(trigger: triggerFeedback)
                .disabled(widget.readOnly ?? false)
            }
        }
    }

    private func decreaseValue(displayState: WidgetDisplayState) {
        handleUpDown(isDecreasing: true, displayState: displayState)
    }

    private func increaseValue(displayState: WidgetDisplayState) {
        handleUpDown(isDecreasing: false, displayState: displayState)
    }

    private func handleUpDown(isDecreasing: Bool, displayState: WidgetDisplayState) {
        var numberState = widget.stateValueAsNumberState
        let currentValue = numberState?.value ?? displayState.minValue

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

        // Use widget's unit as fallback when creating NumberState
        numberState = numberState ?? NumberState(
            value: limitedNewValue,
            unit: widget.unit,
            format: widget.item?.stateDescription?.numberPattern
        )
        numberState?.value = limitedNewValue

        logger.info("Setpoint \(isDecreasing ? "decreased" : "increased") to \(numberState?.description ?? String(limitedNewValue))")
        viewModel.sendToUpdate(item: widget.item, state: numberState, policy: .immediate)
    }

    private func currentValue(displayState: WidgetDisplayState) -> Double {
        widget.stateValueAsNumberState?.value ?? displayState.minValue
    }

    private func formattedValue(displayState: WidgetDisplayState) -> String {
        if let numberState = widget.stateValueAsNumberState {
            return numberState.toString(locale: Locale.current)
        }
        let text = currentValue(displayState: displayState).valueText(step: displayState.step)
        if let unit = widget.unit, !unit.isEmpty {
            return "\(text) \(unit)"
        }
        return text
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[3]
    VStack {
        SetpointRowView(widget: widget)
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
