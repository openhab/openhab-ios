// Copyright (c) 2010-2023 Contributors to the openHAB project
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

class SwitchUITableViewCell: GenericUITableViewCell {
    @IBOutlet private var widgetSwitch: UISwitch!

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        initialize()
    }

    override func initialize() {
        selectionStyle = .none
        separatorInset = .zero
    }

    override func displayWidget() {
        customTextLabel?.text = widget.labelText
        var state = widget.state
        // if state is nil or empty using the item state ( OH 1.x compatability )
        if state.isEmpty {
            state = (widget.item?.state) ?? ""
        }
        customDetailTextLabel?.text = widget.labelValue ?? ""
        widgetSwitch?.isOn = state.parseAsBool()
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
