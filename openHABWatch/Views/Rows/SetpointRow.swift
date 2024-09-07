// Copyright (c) 2010-2024 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import os.log
import SwiftUI

struct SetpointRow: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

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

    private func handleUpDown(down: Bool) {
        var numberState = widget.stateValueAsNumberState
        let stateValue = numberState?.value ?? widget.minValue
        let newValue: Double = switch down {
        case true:
            stateValue - widget.step
        case false:
            stateValue + widget.step
        }
        if newValue >= widget.minValue, newValue <= widget.maxValue {
            numberState?.value = newValue
            widget.sendItemUpdate(state: numberState)
        }
    }

    func decreaseValue() {
        handleUpDown(down: true)
    }

    func increaseValue() {
        handleUpDown(down: false)
    }
}

struct SetpointRow_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[3]
        return SetpointRow(widget: widget)
    }
}
