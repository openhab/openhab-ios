//
//  SliderUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 16/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

class SliderUITableViewCell: GenericUITableViewCell {

    @IBOutlet weak var widgetSlider: UISlider!
    //@IBOutlet weak var customTextLabel: UILabel!
    required init?(coder: NSCoder) {
        super.init(coder: coder)

        selectionStyle = UITableViewCell.SelectionStyle.none
        separatorInset = UIEdgeInsets.zero

    }

    override init (style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = UITableViewCell.SelectionStyle.none
        separatorInset = UIEdgeInsets.zero
    }

    override func displayWidget() {
        customTextLabel?.text = widget.labelText()
        let widgetValue = widget.item?.stateAsFloat()
        widgetSlider?.value = widgetValue! / 100
        widgetSlider?.addTarget(self, action: #selector(SliderUITableViewCell.sliderDidEndSliding(_:)), for: [.touchUpInside, .touchUpOutside])
    }

    @objc func sliderDidEndSliding (_ sender: UISlider) { //(_ notification: Notification?) {
        print("Slider new value = \(widgetSlider?.value ?? 0.0)")
        let intValue = Int((widgetSlider?.value ?? 0.0) * 100)
        widget.sendCommand("\(intValue)")
    }
}
