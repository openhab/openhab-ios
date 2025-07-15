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

import OpenHABCore
import os.log
import SFSafeSymbols
import SwiftUI

struct SetpointRow: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var settings: AppSettings
    private let setpointService = SetPointService()

    private var isIntStep: Bool {
        widget.step.truncatingRemainder(dividingBy: 1) == 0
    }

    private var stateFormat: String {
        isIntStep ? "%ld" : "%.01f"
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                IconView(widget: widget, settings: settings)
                TextLabelView(widget: widget)
                Spacer()
            }
            HStack {
                Spacer()

                IconWithAction(
                    systemSymbol: .chevronDownCircleFill,
                    action: decreaseValue
                )

                Spacer()

                DetailTextLabelView(widget: widget)
                    .font(.headline)

                Spacer()

                IconWithAction(
                    systemSymbol: .chevronUpCircleFill,
                    action: increaseValue
                )

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

        numberState = numberState ?? NumberState(value: limitedNewValue)
        numberState?.value = limitedNewValue

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
