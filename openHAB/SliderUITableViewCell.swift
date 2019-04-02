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
        let widgetValue = widget.item?.stateAsDouble()
        widgetSlider?.value = Float( widgetValue! / 100)
        widgetSlider?.addTarget(self, action: #selector(SliderUITableViewCell.sliderDidEndSliding(_:)), for: [.touchUpInside, .touchUpOutside])
    }

    @objc func sliderDidEndSliding (_ sender: UISlider) { //(_ notification: Notification?) {
        os_log("Slider new value = %{PUBLIC}@", log: .default, type: .info, widgetSlider?.value ?? 0.0)

        let intValue = Int((widgetSlider?.value ?? 0.0) * 100)
        widget.sendCommand("\(intValue)")
    }
}
