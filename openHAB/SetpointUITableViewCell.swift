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
            return 0.0 // MARK - Change this horror
        }
    }

    var intValue: Int {
        if let asNumber = NumberFormatter().number(from: self) {
            return asNumber.intValue
        } else {
            return 0 // MARK - Change this horror
        }
    }
}

class SetpointUITableViewCell: GenericUITableViewCell {
    var widgetSegmentedControl: UISegmentedControl?

    private var isIntStep: Bool {
        return widget.step.floatValue.truncatingRemainder(dividingBy: 1) == 0
    }

    private var stateFormat: String {
        return isIntStep ? "%ld" : "%.01f"
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        widgetSegmentedControl = viewWithTag(300) as? UISegmentedControl
        selectionStyle = UITableViewCell.SelectionStyle.none
        separatorInset = UIEdgeInsets.zero

    }

    override func displayWidget() {
        textLabel?.text = widget.labelText()
        var widgetValue: String
        if widget.item.state == "Uninitialized" {
            widgetValue = "N/A"
        } else {
            if !isIntStep {
                widgetValue = String(format: stateFormat, widget.item.stateAsFloat())
            } else {
                widgetValue = String(format: stateFormat, widget.item.stateAsInt())
            }
        }
        widgetSegmentedControl?.setTitle(widgetValue, forSegmentAt: 1)
        widgetSegmentedControl?.addTarget(self, action: #selector(SetpointUITableViewCell.pickOne(_:)), for: .valueChanged)
    }

    func decreaseValue() {
        if widget.item.state == "Uninitialized" {
            widget.sendCommand(widget.minValue) // as? String)
        } else {
            if widget.minValue != nil {
                if !isIntStep {
                    let newValue = widget.item.stateAsFloat() - widget.step.floatValue
                    if newValue >= widget.minValue.floatValue {
                        widget.sendCommand(String(format: stateFormat, newValue))
                    } else {
                        widget.sendCommand(String(format: stateFormat, widget.minValue))
                    }
                } else {
                    let newValue = widget.item.stateAsInt() - widget.step.intValue
                    if newValue >= Int(widget.minValue.intValue) {
                        widget.sendCommand(String(format: stateFormat, newValue))
                    } else {
                        widget.sendCommand(String(format: stateFormat, widget.minValue.intValue))
                    }
                }
            } else {
                if !isIntStep {
                    widget.sendCommand(String(format: stateFormat, widget.item.stateAsFloat() - widget.step.floatValue))
                } else {
                    widget.sendCommand(String(format: stateFormat, widget.item.stateAsInt() - widget.step.intValue))
                }
            }
        }
    }

    func increaseValue() {
        if widget.item.state == "Uninitialized" {
            widget.sendCommand(widget.minValue )
        } else {
            if widget.maxValue != nil {
                if !isIntStep {
                    let newValue = widget.item.stateAsFloat() + widget.step.floatValue
                    if newValue <= widget.maxValue.floatValue {
                        widget.sendCommand(String(format: stateFormat, newValue))
                    } else {
                        widget.sendCommand(String(format: stateFormat, widget.maxValue))
                    }
                } else {
                    let newValue = widget.item.stateAsInt() + widget.step.intValue
                    if newValue <= Int(widget.maxValue.intValue) {
                        widget.sendCommand(String(format: stateFormat, newValue))
                    } else {
                        widget.sendCommand(String(format: stateFormat, widget.maxValue.intValue))
                    }
                }
            } else {
                if !isIntStep {
                    widget.sendCommand(String(format: stateFormat, widget.item.stateAsFloat() + widget.step.floatValue))
                } else {
                    widget.sendCommand(String(format: stateFormat, widget.item.stateAsInt() + widget.step.intValue))
                }
            }
        }
    }

    @objc func pickOne(_ sender: Any?) {
        let segmentedControl = sender as? UISegmentedControl
        print(String(format: "Setpoint pressed %ld", segmentedControl?.selectedSegmentIndex ?? 0))
        // Deselect segment in the middle
        if segmentedControl?.selectedSegmentIndex == 1 {
            widgetSegmentedControl?.selectedSegmentIndex = -1
            // - pressed
        } else if segmentedControl?.selectedSegmentIndex == 0 {
            decreaseValue()
            // + pressed
        } else if segmentedControl?.selectedSegmentIndex == 2 {
            increaseValue()
        }
    }
}
