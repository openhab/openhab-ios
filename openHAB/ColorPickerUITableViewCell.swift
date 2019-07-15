//
//  ColorPickerUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 16/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import os.log

@objc protocol ColorPickerUITableViewCellDelegate: NSObjectProtocol {
    func didPressColorButton(_ cell: ColorPickerUITableViewCell?)
}

fileprivate extension Selector {
    static let upButtonPressed = #selector(ColorPickerUITableViewCell.upButtonPressed)
    static let downButtonPressed = #selector(ColorPickerUITableViewCell.downButtonPressed)
}

class ColorPickerUITableViewCell: GenericUITableViewCell {
    @IBOutlet weak var upButton: UICircleButton!
    @IBOutlet weak var colorButton: UICircleButton!
    @IBOutlet weak var downButton: UICircleButton!

    @IBAction func colorButtonPressed(_ sender: Any) {
        delegate?.didPressColorButton(self)
    }
    @objc weak var delegate: ColorPickerUITableViewCellDelegate?

    required init?(coder: NSCoder) {
        os_log("ColorPickerUITableViewCell initWithCoder", log: OSLog.viewCycle, type: .info)

        super.init(coder: coder)

        selectionStyle = .none
        separatorInset = .zero
    }

    override init (style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        separatorInset = .zero
    }

    override func displayWidget() {
        customTextLabel?.text = widget.labelText
        colorButton?.backgroundColor = widget.item?.stateAsUIColor()
        upButton?.addTarget(self, action: .upButtonPressed, for: .touchUpInside)
        downButton?.addTarget(self, action: .downButtonPressed, for: .touchUpInside)

    }

    @objc func upButtonPressed() {
        os_log("ON button pressed", log: .viewCycle, type: .info)
        widget.sendCommand("ON")
    }

    @objc func downButtonPressed() {
        os_log("OFF button pressed", log: .viewCycle, type: .info)
        widget.sendCommand("OFF")
    }
}
