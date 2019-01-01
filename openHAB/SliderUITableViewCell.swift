//  Converted to Swift 4 by Swiftify v4.2.28993 - https://objectivec2swift.com/
//
//  SliderUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 16/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

class SliderUITableViewCell: GenericUITableViewCell {
    var widgetSlider: UISlider?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        widgetSlider = viewWithTag(400) as? UISlider
        selectionStyle = UITableViewCell.SelectionStyle.none
        separatorInset = UIEdgeInsets.zero
    
    }

    override func displayWidget() {
        textLabel.text = widget.labelText()
        let widgetValue = widget.item.stateAsFloat()
        widgetSlider?.value = widgetValue / 100
        widgetSlider?.addTarget(self, action: #selector(SliderUITableViewCell.sliderDidEndSliding(_:)), for: [.touchUpInside, .touchUpOutside])
    }

    @objc func sliderDidEndSliding(_ notification: Notification?) {
        print("Slider new value = \(widgetSlider?.value ?? 0.0)")
        let intValue = Int((widgetSlider?.value ?? 0.0) * 100)
        widget.sendCommand("\(intValue)")
    }
}
