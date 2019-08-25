//
//  ColorPickerUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 16/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import DynamicButton
import os.log

@objc protocol ColorPickerUITableViewCellDelegate: NSObjectProtocol {
    func didPressColorButton(_ cell: ColorPickerUITableViewCell?)
}

class ColorPickerUITableViewCell: GenericUITableViewCell {

    @objc weak var delegate: ColorPickerUITableViewCellDelegate?

    @IBOutlet weak var upButton: DynamicButton!
    @IBOutlet weak var colorButton: UICircleButton!
    @IBOutlet weak var downButton: DynamicButton!

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

    @IBAction func colorButtonPressed(_ sender: Any) {
        delegate?.didPressColorButton(self)
    }

    override func displayWidget() {
        downButton.setStyle(.caretDown, animated: false)
        upButton.setStyle(.caretUp, animated: false)

        customTextLabel?.text = widget.labelText
        colorButton?.backgroundColor = widget.item?.stateAsUIColor()
        upButton?.addTarget(self, action: .upButtonPressed, for: .touchUpInside)
        downButton?.addTarget(self, action: .downButtonPressed, for: .touchUpInside)
        downButton?.highlightStokeColor = Colors.hightlightStrokeColor
        upButton?.highlightStokeColor =  Colors.hightlightStrokeColor
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

fileprivate extension Selector {
    static let upButtonPressed = #selector(ColorPickerUITableViewCell.upButtonPressed)
    static let downButtonPressed = #selector(ColorPickerUITableViewCell.downButtonPressed)
}
