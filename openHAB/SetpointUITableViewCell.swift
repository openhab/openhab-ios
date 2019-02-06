//
//  SetpointUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 16/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

extension String {

    var floatValue: Float {
        if let asNumber = NumberFormatter().number(from: self) {
            return asNumber.floatValue
        } else {
            return Float.nan
        }
    }

    var intValue: Int {
        if let asNumber = NumberFormatter().number(from: self) {
            return asNumber.intValue
        } else {
            return Int.max
        }
    }
}

class SetpointUITableViewCell: GenericUITableViewCell {
    @IBOutlet weak var widgetSegmentControl: UISegmentedControl!

    private var isIntStep: Bool {
        return widget.step.floatValue.truncatingRemainder(dividingBy: 1) == 0
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
                widgetValue = String(format: stateFormat, (widget.item?.stateAsFloat())!)
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
                    var newValue = item.stateAsFloat() - widget.step.floatValue
                    if widget.minValue != "" {
                        newValue = max(newValue, widget.minValue.floatValue)
                    }
                    widget.sendCommand(String(format: stateFormat, newValue))
                } else {
                    var newValue = item.stateAsInt() - widget.step.intValue
                    if widget.minValue != "" {
                        newValue = max(newValue, widget.minValue.intValue)
                    }
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
                if widget.maxValue != "" {
                    if !isIntStep {
                        var newValue = item.stateAsFloat() + widget.step.floatValue
                        if widget.minValue != "" {
                            newValue = min(newValue, widget.maxValue.floatValue)
                        }
                        widget.sendCommand(String(format: stateFormat, newValue))
                    } else {
                        var newValue = item.stateAsInt() + widget.step.intValue
                        if widget.minValue != "" {
                            newValue = min(newValue, widget.maxValue.intValue)
                        }
                        widget.sendCommand(String(format: stateFormat, newValue))
                    }
                } else {
                    if !isIntStep {
                        widget.sendCommand(String(format: stateFormat, item.stateAsFloat() + widget.step.floatValue))
                    } else {
                        widget.sendCommand(String(format: stateFormat, item.stateAsInt() + widget.step.intValue))
                    }
                }
            }
        }
    }

    @objc func pickOne(_ sender: Any?) {
        let segmentedControl = sender as? UISegmentedControl
        print(String(format: "Setpoint pressed %ld", segmentedControl?.selectedSegmentIndex ?? 0))
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
