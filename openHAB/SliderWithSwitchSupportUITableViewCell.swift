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

import Alamofire
import AVFoundation
import AVKit
import OpenHABCore
import os.log

class SliderWithSwitchSupportUITableViewCell: GenericUITableViewCell {
    private var step: Float = 1.0

    private var widgetValue: Double {
        adj(Double(widgetSlider?.value ?? Float(widget.minValue)))
    }

    @IBOutlet private var widgetSlider: UISlider!
    @IBOutlet private var widgetSwitch: UISwitch!
    @IBOutlet private var customDetailText: UILabel!

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        initialize()
    }

    @IBAction private func sliderValueChanged(_ sender: UISlider) {
        customDetailText?.text = widgetValue.valueText(step: widget.step)
        // Calling sliderDidChange leads to interference with other cells.
        // sliderDidChange(toValue: widgetValue)
    }

    @IBAction private func sliderTouchUp(_ sender: UISlider) {
        sliderDidChange(toValue: widgetValue)
        touchEventDelegate?.touchUp()
    }

    @IBAction private func sliderTouchDown(_ sender: UISlider) {
        touchEventDelegate?.touchDown()
    }

    @IBAction private func sliderTouchOutside(_ sender: UISlider) {
        sliderTouchUp(sender)
    }

    override public func initialize() {
        selectionStyle = .none
        separatorInset = .zero
        if let widget {
            step = Float(widget.step)
        } else {
            step = 1.0
        }
    }

    private func adj(_ raw: Double) -> Double {
        var valueAdjustedToStep = Double(floor(Float(((raw - widget.minValue))) / step) * step)
        valueAdjustedToStep += widget.minValue
        return valueAdjustedToStep.clamped(to: widget.minValue ... widget.maxValue)
    }

    private func adjustedValue() -> Double {
        if let item = widget.item {
            adj(item.stateAsDouble())
        } else {
            widget.minValue
        }
    }

    override func displayWidget() {
        // guard !isInTransition else { return }

        customTextLabel?.text = widget.labelText
        var state = widget.state
        // if state is nil or empty using the item state ( OH 1.x compatability )
        if state.isEmpty {
            state = (widget.item?.state) ?? ""
        }
        widgetSwitch?.isOn = state.parseAsBool()
        widgetSwitch?.addTarget(self, action: .switchChange, for: .valueChanged)
        super.displayWidget()

        if let item = widget.item, item.isOfTypeOrGroupType(.color) {
            widgetSlider?.minimumValue = 0.0
            widgetSlider?.maximumValue = 100.0
            step = 1.0
            widgetSlider.value = Float(item.state?.parseAsBrightness() ?? 0)
        } else {
            // Fix "The stepSize must be 0, or a factor of the valueFrom-valueTo range" exception
            widgetSlider?.minimumValue = Float(widget.minValue)
            widgetSlider?.maximumValue = Float(widget.maxValue)
            let widgetValue = adjustedValue()
            widgetSlider?.value = Float(widgetValue)
            step = Float(widget.step)

            // if there is a formatted value in widget label, take it. Otherwise display local value
            if let labelValue = widget?.labelValue {
                customDetailText?.text = labelValue
            } else {
                customDetailText?.text = widgetValue.valueText(step: Double(step))
            }
        }
        customTextLabel?.text = widget.labelText
    }

    private func sliderDidChange(toValue value: Double) {
        os_log("Slider new value = %g", log: .default, type: .info, value)
        widget.sendCommand(value.valueText(step: Double(step)))
    }

    @objc
    func switchChange() {
        if (widgetSwitch?.isOn)! {
            os_log("Switch to ON", log: .viewCycle, type: .info)
            widget.sendCommand("ON")
        } else {
            os_log("Switch to OFF", log: .viewCycle, type: .info)
            widget.sendCommand("OFF")
        }
    }
}

private extension Selector {
    static let switchChange = #selector(SwitchUITableViewCell.switchChange)
}
