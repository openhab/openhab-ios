//
//  SetpointUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 16/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//
import DynamicButton
import os.log

class SetpointUITableViewCell: GenericUITableViewCell {
    @IBOutlet weak var downButton: DynamicButton!
    @IBOutlet weak var upButton: DynamicButton!

    private var isIntStep: Bool {
        return widget.step.truncatingRemainder(dividingBy: 1) == 0
    }

    private var stateFormat: String {
        return isIntStep ? "%ld" : "%.01f"
    }

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

        downButton.highlightStokeColor = Colors.hightlightStrokeColor
        upButton.highlightStokeColor =  Colors.hightlightStrokeColor

        super.displayWidget()
    }

    @objc func decreaseValue(_ sender: Any?) {
        os_log("down button pressed", log: .viewCycle, type: .info)

        if let item = widget.item {
            if item.state == "Uninitialized" {
                widget.sendCommand(widget.minValue)
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

    @objc func increaseValue(_ sender: Any?) {
        os_log("up button pressed", log: .viewCycle, type: .info)

        if let item = widget.item {
            if item.state == "Uninitialized" {
                widget.sendCommand(widget.minValue)
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
