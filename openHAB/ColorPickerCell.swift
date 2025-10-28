// Copyright (c) 2010-2025 Contributors to the openHAB project
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
    weak var delegate: (any ColorPickerCellDelegate)?

    @IBOutlet private var downButton: UIButton!
    @IBOutlet private var upButton: UIButton!
    @IBOutlet private var colorButton: UICircleButton!

    required init?(coder: NSCoder) {
        Logger.widgets.info("ColorPickerCell initWithCoder")

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
        Logger.widgets.info("ON button pressed")
        widget.sendCommand("ON")
    }

    @objc
    func downButtonPressed() {
        Logger.widgets.info("OFF button pressed")
        widget.sendCommand("OFF")
    }
}

private extension Selector {
    static let upButtonPressed = #selector(ColorPickerCell.upButtonPressed)
    static let downButtonPressed = #selector(ColorPickerCell.downButtonPressed)
}
