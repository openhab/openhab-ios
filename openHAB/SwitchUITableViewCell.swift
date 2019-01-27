//
//  SwitchUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 16/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

class SwitchUITableViewCell: GenericUITableViewCell {

    @IBOutlet var widgetSwitch: UISwitch!
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
        self.customTextLabel?.text = widget.labelText()
        var state = widget.state
        //if state is nil or empty using the item state ( OH 1.x compatability )
        if state.count == 0 {
            state = (widget.item?.state)!
        }
        if let customDetailText = widget.labelValue() {
            self.customDetailTextLabel?.text = customDetailText
        } else {
            self.customDetailTextLabel?.text = ""
        }
        if state == "ON" {
            widgetSwitch?.isOn = true
        } else {
            widgetSwitch?.isOn = false
        }
        widgetSwitch?.addTarget(self, action: #selector(SwitchUITableViewCell.switchChange(_:)), for: .valueChanged)
        super.displayWidget()
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
