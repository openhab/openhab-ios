// Copyright (c) 2010-2019 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import DynamicButton
import os.log
import UIKit

class SetpointUITableViewCell: GenericUITableViewCell {
    private var isIntStep: Bool {
        return widget.step.truncatingRemainder(dividingBy: 1) == 0
    }

    private var stateFormat: String {
        return isIntStep ? "%ld" : "%.01f"
    }

    @IBOutlet private var downButton: DynamicButton!
    @IBOutlet private var upButton: DynamicButton!

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        selectionStyle = .none
        separatorInset = .zero
    }

    override func displayWidget() {
        downButton.setStyle(.caretDown, animated: false)
        upButton.setStyle(.caretUp, animated: false)

        downButton.addTarget(self, action: #selector(SetpointUITableViewCell.decreaseValue), for: .touchUpInside)
        upButton.addTarget(self, action: #selector(SetpointUITableViewCell.increaseValue), for: .touchUpInside)

        downButton.highlightStokeColor = .ohHightlightStrokeColor
        upButton.highlightStokeColor = .ohHightlightStrokeColor

        super.displayWidget()
    }

    @objc
    func decreaseValue(_ sender: Any?) {
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

    @objc
    func increaseValue(_ sender: Any?) {
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
