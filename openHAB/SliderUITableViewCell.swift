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
    private var isInTransition: Bool = false
    private var transitionItem: DispatchWorkItem?
    private var throttler: Throttler?
    private var throttlingInterval: TimeInterval? = 0 {
        didSet {
            guard let interval = throttlingInterval else {
                throttler = nil
                return
            }
            throttler = Throttler(maxInterval: interval)
        }
    }

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
        throttlingInterval = 0.1
    }

    @IBAction private func sliderValueChanged(_ sender: Any) {
        let widgetValue = adj(Double(widgetSlider?.value ?? Float(widget.minValue)))
        customDetailText?.text = valueText(widgetValue)
        transitionItem?.cancel()
        isInTransition = true
        throttler?.throttle { DispatchQueue.main.async { self.sliderDidChange(toValue: widgetValue) } }
    }

    @IBAction private func sliderTouchUp(_ sender: Any) {
        stopTransitionDelayed()
    }

    @IBAction private func sliderTouchOutside(_ sender: Any) {
        stopTransitionDelayed()
    }

    private func stopTransitionDelayed() {
        transitionItem = DispatchWorkItem { [weak self] in
            self?.isInTransition = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: transitionItem!)
    }

    private func adj(_ raw: Double) -> Double {
        var valueAdjustedToStep = floor((raw - widget.minValue) / widget.step) * widget.step
        valueAdjustedToStep += widget.minValue
        return min(max(valueAdjustedToStep, widget.minValue), widget.maxValue)
    }

    private func adjustedValue() -> Double {
        if let item = widget.item {
            return adj(item.stateAsDouble())
        } else {
            return widget.minValue
        }
    }

    private func valueText(_ widgetValue: Double) -> String {
        let digits = max(-Decimal(widget.step).exponent, 0)
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = digits
        numberFormatter.decimalSeparator = "."
        return numberFormatter.string(from: NSNumber(value: widgetValue)) ?? ""
    }

    override func displayWidget() {
        guard !isInTransition else { return }

        customTextLabel?.text = widget.labelText
        widgetSlider?.minimumValue = Float(widget.minValue)
        widgetSlider?.maximumValue = Float(widget.maxValue)
        let widgetValue = adjustedValue()
        widgetSlider?.value = Float(widgetValue)
        customDetailText?.text = valueText(widgetValue)
    }

    private func sliderDidChange(toValue value: Double) {
        os_log("Slider new value = %g", log: .default, type: .info, value)
        widget.sendCommandDouble(value)
    }
}
