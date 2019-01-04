//  Converted to Swift 4 by Swiftify v4.2.28993 - https://objectivec2swift.com/
//
//  SwitchUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 16/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

class SwitchUITableViewCell: GenericUITableViewCell {
    var widgetSwitch: UISwitch?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        widgetSwitch = viewWithTag(200) as? UISwitch
        selectionStyle = UITableViewCell.SelectionStyle.none
        separatorInset = UIEdgeInsets.zero
    
    }

    override func displayWidget() {
        textLabel.text = widget.labelText()
        var state = widget.state
        //if state is nil or empty using the item state ( OH 1.x compatability )
        if state?.count == 0 {
            state = widget.item.state
        }
        if widget.labelValue() != nil {
            detailTextLabel?.text = widget.labelValue()
        } else {
            detailTextLabel?.text = nil
        }
        if (state == "ON") {
            widgetSwitch?.isOn = true
        } else {
            widgetSwitch?.isOn = false
        }
        //    NSLog(@"%f %f %f %f", self.textLabel.frame.origin.x, self.textLabel.frame.origin.y, self.textLabel.frame.size.width, self.textLabel.frame.size.height);
        widgetSwitch?.addTarget(self, action: #selector(SwitchUITableViewCell.switchChange(_:)), for: .valueChanged)
    }

    @objc func switchChange(_ sender: Any?) {
        if (widgetSwitch?.isOn)! {
            print("Switch to ON")
            widget.sendCommand("ON")
        } else {
            print("Switch to OFF")
            widget.sendCommand("OFF")
        }
    }
}
