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
    var upButton: UICircleButton?
    var colorButton: UICircleButton?
    var downButton: UICircleButton?
    @objc weak var delegate: ColorPickerUITableViewCellDelegate?

    required init?(coder: NSCoder) {
        print("RollershutterUITableViewCell initWithCoder")
        super.init(coder: coder)

//        upButton = viewWithTag(701) as? UICircleButton
//        colorButton = viewWithTag(702) as? UICircleButton
//        downButton = viewWithTag(703) as? UICircleButton

        upButton?.setTitle("▲", for: .normal)
        downButton?.setTitle("▼", for: .normal)

        upButton?.addTarget(self, action: #selector(ColorPickerUITableViewCell.upButtonPressed), for: .touchUpInside)
        colorButton?.addTarget(self, action: #selector(ColorPickerUITableViewCell.colorButtonPressed), for: .touchUpInside)
        downButton?.addTarget(self, action: #selector(ColorPickerUITableViewCell.downButtonPressed), for: .touchUpInside)
        selectionStyle = UITableViewCell.SelectionStyle.none
        separatorInset = UIEdgeInsets.zero

    }

    override init (style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

//        upButton = viewWithTag(701) as? UICircleButton
//        colorButton = viewWithTag(702) as? UICircleButton
//        downButton = viewWithTag(703) as? UICircleButton

        upButton?.setTitle("▲", for: .normal)
        downButton?.setTitle("▼", for: .normal)

        upButton?.addTarget(self, action: #selector(ColorPickerUITableViewCell.upButtonPressed), for: .touchUpInside)
        colorButton?.addTarget(self, action: #selector(ColorPickerUITableViewCell.colorButtonPressed), for: .touchUpInside)
        downButton?.addTarget(self, action: #selector(ColorPickerUITableViewCell.downButtonPressed), for: .touchUpInside)
        selectionStyle = UITableViewCell.SelectionStyle.none
        separatorInset = UIEdgeInsets.zero

    }

    override func displayWidget() {
        customTextLabel?.text = widget.labelText()
        colorButton?.backgroundColor = widget.item.stateAsUIColor()
    }

    @objc func upButtonPressed() {
        widget.sendCommand("ON")
    }

    @objc func colorButtonPressed() {
        if delegate != nil {
            delegate?.didPressColorButton(self)
        }
    }

    @objc func downButtonPressed() {
        widget.sendCommand("OFF")
    }
}
