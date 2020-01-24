//
//  SetpointRow.swift
//  openHABWatchSwift Extension
//
//  Created by Tim Müller-Seydlitz on 24.01.20.
//  Copyright © 2020 openHAB e.V. All rights reserved.
//

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

                       Image(systemName: "chevron.down")
                       .onTapGesture {
                           self.decreaseValue()
                       }
                       .font(.headline)

                       Spacer()

                       DetailTextLabelView(widget: widget)

                       Spacer()

                       Image(systemName: "chevron.up")
                       .onTapGesture {
                           self.increaseValue()
                       }
                       .font(.headline)

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
