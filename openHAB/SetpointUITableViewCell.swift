//
//  SetpointUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 16/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//
import os.log

class SetpointUITableViewCell: GenericUITableViewCell {
    @IBOutlet weak var widgetSegmentControl: UISegmentedControl!

    private var isIntStep: Bool {
        return widget.step.truncatingRemainder(dividingBy: 1) == 0
    }

    private var stateFormat: String {
        return isIntStep ? "%ld" : "%.01f"
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        selectionStyle = UITableViewCell.SelectionStyle.none
        separatorInset = UIEdgeInsets.zero

    }

    override func displayWidget() {
        self.customTextLabel?.text = widget.labelText()
        var widgetValue: String
        if widget.item?.state == "Uninitialized" {
            widgetValue = "N/A"
        } else {
            if !isIntStep {
                widgetValue = String(format: stateFormat, (widget.item?.stateAsDouble())!)
            } else {
                widgetValue = String(format: stateFormat, (widget.item?.stateAsInt())!)
            }
        }
        widgetSegmentControl?.setTitle(widgetValue, forSegmentAt: 1)
        widgetSegmentControl?.addTarget(self, action: #selector(SetpointUITableViewCell.pickOne(_:)), for: .valueChanged)
        super.displayWidget()
    }

    func decreaseValue() {
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

    func increaseValue() {
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

    @objc func pickOne(_ sender: Any?) {
        let segmentedControl = sender as? UISegmentedControl
        os_log("Setpoint pressed %d", log: .default, type: .info, segmentedControl?.selectedSegmentIndex ?? 0)

        // Deselect segment in the middle
        if segmentedControl?.selectedSegmentIndex == 1 {
            widgetSegmentControl?.selectedSegmentIndex = -1
            // - pressed
        } else if segmentedControl?.selectedSegmentIndex == 0 {
            decreaseValue()
            // + pressed
        } else if segmentedControl?.selectedSegmentIndex == 2 {
            increaseValue()
        }
    }
}
