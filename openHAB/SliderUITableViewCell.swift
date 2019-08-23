//
//  SliderUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 16/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import os.log
import UIKit

class SliderUITableViewCell: GenericUITableViewCell {

    @IBOutlet weak var widgetSlider: UISlider!

    @IBAction func sliderValueChanged(_ sender: Any) {
        let widgetValue = adj(Double(widgetSlider?.value ?? Float (widget.minValue)))
        customDetailText?.text = valueText(widgetValue)
    }

    @IBAction func sliderTouchUp(_ sender: Any) {
        sliderDidEndSliding(widgetSlider)
    }

    @IBAction func sliderTouchOutside(_ sender: Any) {
        sliderDidEndSliding(widgetSlider)
    }

    @IBOutlet weak var customDetailText: UILabel!

    private func initiliaze() {
        selectionStyle = .none
        separatorInset = .zero
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.initiliaze()
    }

    override init (style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.initiliaze()
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
        let digits = max (-Decimal(widget.step).exponent, 0)
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = digits
        numberFormatter.decimalSeparator  = "."
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

    @objc func sliderDidEndSliding (_ sender: UISlider) {
        let res = adj(Double(widgetSlider!.value))
        os_log("Slider new value = %g, adjusted to %g", log: .default, type: .info, widgetSlider!.value, res)
        widget.sendCommand(valueText(res))
    }
}
