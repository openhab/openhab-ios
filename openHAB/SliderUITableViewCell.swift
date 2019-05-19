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

class SliderUITableViewCell: GenericUITableViewCell {

    @IBOutlet weak var widgetSlider: UISlider!
    //@IBOutlet weak var customTextLabel: UILabel!

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

    override func displayWidget() {
        customTextLabel?.text = widget.labelText()
        if let item = widget.item {
            widgetSlider?.minimumValue = Float(widget.minValue)
            widgetSlider?.maximumValue = Float(widget.maxValue)
            let valueAdjustedToStep = floor((item.stateAsDouble() - widget.minValue) / widget.step) + widget.minValue
            let widgetValue = min(max(valueAdjustedToStep, widget.minValue), widget.maxValue)
            widgetSlider?.value = Float(widgetValue)

            widgetSlider?.addTarget(self, action: #selector(SliderUITableViewCell.sliderDidEndSliding(_:)), for: [.touchUpInside, .touchUpOutside])
        }
    }

    @objc func sliderDidEndSliding (_ sender: UISlider) {
        os_log("Slider new value = %g", log: .default, type: .info, widgetSlider?.value ?? 0.0)
        let input = Double(widgetSlider?.value ?? Float (widget.minValue))
        let minV = widget.minValue
        let res = floor(( input - minV) / widget.step) * widget.step + widget.minValue
        widget.sendCommand("\(res)")
    }
}
