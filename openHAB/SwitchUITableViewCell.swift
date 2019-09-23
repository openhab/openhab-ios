//
//  SwitchUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 16/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//
import os.log
import UIKit

class SwitchUITableViewCell: GenericUITableViewCell {
    @IBOutlet private var widgetSwitch: UISwitch!

    override func initialize() {
        selectionStyle = .none
        separatorInset = .zero
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        initialize()
    }

    override func displayWidget() {
        customTextLabel?.text = widget.labelText
        var state = widget.state
        // if state is nil or empty using the item state ( OH 1.x compatability )
        if state.isEmpty {
            state = (widget.item?.state) ?? ""
        }
        customDetailTextLabel?.text = widget.labelValue ?? ""
        widgetSwitch?.isOn = (state == "ON" ? true : false)
        widgetSwitch?.addTarget(self, action: .switchChange, for: .valueChanged)
        super.displayWidget()
    }

    @objc
    func switchChange() {
        if (widgetSwitch?.isOn)! {
            os_log("Switch to ON", log: .viewCycle, type: .info)
            widget.sendCommand("ON")
        } else {
            os_log("Switch to OFF", log: .viewCycle, type: .info)
            widget.sendCommand("OFF")
        }
    }
}

private extension Selector {
    static let switchChange = #selector(SwitchUITableViewCell.switchChange)
}
