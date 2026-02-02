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

struct SetpointRow: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var settings: AppSettings
    private let setpointService = SetPointService()
    private let logger = Logger(subsystem: "org.openhab.watch", category: "SetpointRow")

    private var isIntStep: Bool {
        widget.step.truncatingRemainder(dividingBy: 1) == 0
    }

    private var stateFormat: String {
        isIntStep ? "%ld" : "%.01f"
    }

    private var currentValue: Double {
        widget.stateValueAsNumberState?.value ?? widget.minValue
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                IconView(widget: widget, settings: settings)
                TextLabelView(widget: widget, font: .caption, lineLimit: 2)
                Spacer()
            }
            HStack {
                Spacer()

                Button(action: decreaseValue) {
                    Image(systemSymbol: .chevronDownCircleFill)
                        .font(.system(size: 25))
                        .foregroundStyle(currentValue <= widget.minValue ? Color.gray : Color.blue)
                }
                .buttonStyle(.plain)
                .disabled(currentValue <= widget.minValue)

                Spacer()

                DetailTextLabelView(widget: widget)
                    .font(.headline)

                Spacer()

                Button(action: increaseValue) {
                    Image(systemSymbol: .chevronUpCircleFill)
                        .font(.system(size: 25))
                        .foregroundStyle(currentValue >= widget.maxValue ? Color.gray : Color.blue)
                }
                .buttonStyle(.plain)
                .disabled(currentValue >= widget.maxValue)

                Spacer()
            }
        }
    }

    private func handleUpDown(isDecreasing: Bool) {
        var numberState = widget.stateValueAsNumberState
        let currentValue = numberState?.value ?? widget.minValue

        let limitedNewValue = setpointService.calculateNewValue(
            currentValue: currentValue,
            step: widget.step,
            minValue: widget.minValue,
            maxValue: widget.maxValue,
            isDecreasing: isDecreasing
        )

        guard limitedNewValue != currentValue else {
            // nothing to update, skip sending value
            return
        }

        // Use widget's unit as fallback when creating NumberState
        numberState = numberState ?? NumberState(value: limitedNewValue, unit: widget.unit)
        numberState?.value = limitedNewValue

        logger.info("Setpoint \(isDecreasing ? "decreased" : "increased") to \(numberState?.description ?? String(limitedNewValue))")
        widget.sendItemUpdate(state: numberState)
    }

    func decreaseValue() {
        handleUpDown(isDecreasing: true)
    }

    func increaseValue() {
        handleUpDown(isDecreasing: false)
    }
}

#Preview {
    let widget = UserData(preview: true).widgets[3]
    SetpointRow(widget: widget)
        .environmentObject(AppSettings())
}
