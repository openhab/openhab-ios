// Copyright (c) 2010-2024 Contributors to the openHAB project
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

protocol ColorPickerCellDelegate: NSObjectProtocol {
    func didPressColorButton(_ cell: ColorPickerCell?)
}

class ColorPickerCell: GenericUITableViewCell {
    weak var delegate: ColorPickerCellDelegate?

    @IBOutlet private var downButton: UIButton!
    @IBOutlet private var upButton: UIButton!
    @IBOutlet private var colorButton: UICircleButton!

    required init?(coder: NSCoder) {
        os_log("ColorPickerCell initWithCoder", log: OSLog.viewCycle, type: .info)

        super.init(coder: coder)

        selectionStyle = .none
        separatorInset = .zero
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        separatorInset = .zero
    }

    @IBAction private func colorButtonPressed(_ sender: Any) {
        delegate?.didPressColorButton(self)
    }

    override func displayWidget() {
        customTextLabel?.text = widget.labelText
        colorButton?.backgroundColor = widget.item?.stateAsUIColor()
        upButton?.addTarget(self, action: .upButtonPressed, for: .touchUpInside)
        downButton?.addTarget(self, action: .downButtonPressed, for: .touchUpInside)
    }

    @objc
    func upButtonPressed() {
        os_log("ON button pressed", log: .viewCycle, type: .info)
        widget.sendCommand("ON")
    }

    @objc
    func downButtonPressed() {
        os_log("OFF button pressed", log: .viewCycle, type: .info)
        widget.sendCommand("OFF")
    }
}

private extension Selector {
    static let upButtonPressed = #selector(ColorPickerCell.upButtonPressed)
    static let downButtonPressed = #selector(ColorPickerCell.downButtonPressed)
}
