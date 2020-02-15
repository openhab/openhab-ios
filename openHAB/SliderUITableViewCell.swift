// Copyright (c) 2010-2020 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import OpenHABCore
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

    private var widgetValue: Double {
        adj(Double(widgetSlider?.value ?? Float(widget.minValue)))
    }

    @IBOutlet private var widgetSlider: UISlider!
    @IBOutlet private var customDetailText: UILabel!

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        initialize()
    }

    override public func initialize() {
        selectionStyle = .none
        separatorInset = .zero
        throttlingInterval = 0.1
    }

    @IBAction private func sliderValueChanged(_ sender: Any) {
        customDetailText?.text = widgetValue.valueText(step: widget.step)

        if Preferences.realTimeSliders {
            transitionItem?.cancel()
            isInTransition = true
            throttler?.throttle { DispatchQueue.main.async { self.sliderDidChange(toValue: self.widgetValue) } }
        }
    }

    @IBAction private func sliderTouchUp(_ sender: Any) {
        if Preferences.realTimeSliders {
            stopTransitionDelayed()
        } else {
            sliderDidChange(toValue: widgetValue)
        }
    }

    @IBAction private func sliderTouchOutside(_ sender: Any) {
        sliderTouchUp(sender)
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

    override func displayWidget() {
        guard !isInTransition else { return }

        customTextLabel?.text = widget.labelText
        widgetSlider?.minimumValue = Float(widget.minValue)
        widgetSlider?.maximumValue = Float(widget.maxValue)
        let widgetValue = adjustedValue()
        widgetSlider?.value = Float(widgetValue)
        // if there is a formatted value in widget label, take it. Otherwise display local value
        if let labelValue = widget?.labelValue {
            customDetailText?.text = labelValue
        } else {
            customDetailText?.text = widgetValue.valueText(step: widget.step)
        }
    }

    private func sliderDidChange(toValue value: Double) {
        os_log("Slider new value = %g", log: .default, type: .info, value)
        widget.sendCommand(value.valueText(step: widget.step))
    }
}
