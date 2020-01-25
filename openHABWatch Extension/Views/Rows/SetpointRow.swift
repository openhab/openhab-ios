// Copyright (c) 2010-2020 Contributors to the openHAB project
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

// swiftlint:disable file_types_order
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
        VStack {
            HStack {
                IconView(widget: widget, settings: settings)
                TextLabelView(widget: widget)
                Spacer()
            }
            HStack {
                Spacer()

                EncircledIconWithAction(systemName: "chevron.down",
                              action: self.decreaseValue)

                Spacer()

                DetailTextLabelView(widget: widget)
                    .font(.headline)

                Spacer()

                EncircledIconWithAction(systemName: "chevron.up",
                              action: self.increaseValue)

                Spacer()
            }
            .frame(height: 50)
        }
    }

    func decreaseValue() {
        os_log("down button pressed", log: .viewCycle, type: .info)
        if let item = widget.item {
            if item.state == "Uninitialized" {
                widget.sendCommandDouble(widget.minValue)
            } else {
                if !isIntStep {
                    var newValue = item.stateAsDouble() - widget.step
                    newValue = max(newValue, widget.minValue)
                    widget.sendCommand(String(format: stateFormat, newValue))
                } else {
                    var newValue = item.stateAsInt() - Int(widget.step)
                    newValue = max(newValue, Int(widget.minValue))
                    widget.sendCommand(String(format: stateFormat, newValue))
                }
            }
        }
    }

    func increaseValue() {
        os_log("up button pressed", log: .viewCycle, type: .info)

        if let item = widget.item {
            if item.state == "Uninitialized" {
                widget.sendCommandDouble(widget.minValue)
            } else {
                if !isIntStep {
                    var newValue = item.stateAsDouble() + widget.step
                    newValue = min(newValue, widget.maxValue)
                    widget.sendCommand(String(format: stateFormat, newValue))
                } else {
                    var newValue = item.stateAsInt() + Int(widget.step)
                    newValue = min(newValue, Int(widget.maxValue))
                    widget.sendCommand(String(format: stateFormat, newValue))
                }
            }
        }
    }
}

struct SetpointRow_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[3]
        return SetpointRow(widget: widget)
    }
}
