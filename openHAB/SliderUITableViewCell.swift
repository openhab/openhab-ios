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

import os.log
import UIKit

class SliderUITableViewCell: GenericUITableViewCell {
    @IBOutlet private var widgetSlider: UISlider!

    @IBOutlet private var customDetailText: UILabel!

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initiliaze()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        initiliaze()
    }

    private func initiliaze() {
        selectionStyle = .none
        separatorInset = .zero
    }

    @IBAction private func sliderValueChanged(_ sender: Any) {
        let widgetValue = adj(Double(widgetSlider?.value ?? Float(widget.minValue)))
        customDetailText?.text = valueText(widgetValue)
    }

    @IBAction private func sliderTouchUp(_ sender: Any) {
        sliderDidEndSliding(widgetSlider)
    }

    @IBAction private func sliderTouchOutside(_ sender: Any) {
        sliderDidEndSliding(widgetSlider)
    }

    func adj(_ raw: Double) -> Double {
        var valueAdjustedToStep = floor((raw - widget.minValue) / widget.step) * widget.step
        valueAdjustedToStep += widget.minValue
        return min(max(valueAdjustedToStep, widget.minValue), widget.maxValue)
    }

    func adjustedValue() -> Double {
        if let item = widget.item {
            return adj(item.stateAsDouble())
        } else {
            return widget.minValue
        }
    }

    func valueText(_ widgetValue: Double) -> String {
        let digits = max(-Decimal(widget.step).exponent, 0)
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = digits
        numberFormatter.decimalSeparator = "."
        return numberFormatter.string(from: NSNumber(value: widgetValue)) ?? ""
    }

    override func displayWidget() {
        customTextLabel?.text = widget.labelText
        widgetSlider?.minimumValue = Float(widget.minValue)
        widgetSlider?.maximumValue = Float(widget.maxValue)
        let widgetValue = adjustedValue()
        widgetSlider?.value = Float(widgetValue)
        customDetailText?.text = valueText(widgetValue)
    }

    @objc
    func sliderDidEndSliding(_ sender: UISlider) {
        let res = adj(Double(widgetSlider!.value))
        os_log("Slider new value = %g, adjusted to %g", log: .default, type: .info, widgetSlider!.value, res)
        widget.sendCommand(valueText(res))
    }
}
