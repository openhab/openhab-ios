//
//  ColorPickerUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 16/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

@objc protocol ColorPickerUITableViewCellDelegate: NSObjectProtocol {
    func didPressColorButton(_ cell: ColorPickerUITableViewCell?)
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
        print("RollershutterUITableViewCell initWithCoder")
        super.init(coder: coder)

        upButton?.addTarget(self, action: #selector(ColorPickerUITableViewCell.upButtonPressed), for: .touchUpInside)
        downButton?.addTarget(self, action: #selector(ColorPickerUITableViewCell.downButtonPressed), for: .touchUpInside)
        selectionStyle = .none
        separatorInset = .zero

    }

    override init (style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        upButton?.addTarget(self, action: #selector(ColorPickerUITableViewCell.upButtonPressed), for: .touchUpInside)
        downButton?.addTarget(self, action: #selector(ColorPickerUITableViewCell.downButtonPressed), for: .touchUpInside)
        selectionStyle = .none
        separatorInset = .zero

    }

    override func displayWidget() {
        customTextLabel?.text = widget.labelText()

        colorButton?.backgroundColor = widget.item?.stateAsUIColor()
    }

    @objc func upButtonPressed() {
        widget.sendCommand("ON")
    }

    @objc func downButtonPressed() {
        widget.sendCommand("OFF")
    }
}
