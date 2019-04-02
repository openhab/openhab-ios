//
//  RollershutterUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 27/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import os.log

class RollershutterUITableViewCell: GenericUITableViewCell {

    @IBOutlet weak var downButton: UICircleButton!
    @IBOutlet weak var stopButton: UICircleButton!
    @IBOutlet weak var upButton: UICircleButton!

    override func initialize() {

        upButton?.setTitle("▲", for: .normal)
        stopButton?.setTitle("■", for: .normal)
        downButton?.setTitle("▼", for: .normal)

        upButton?.addTarget(self, action: #selector(RollershutterUITableViewCell.upButtonPressed), for: .touchUpInside)
        stopButton?.addTarget(self, action: #selector(RollershutterUITableViewCell.stopButtonPressed), for: .touchUpInside)
        downButton?.addTarget(self, action: #selector(RollershutterUITableViewCell.downButtonPressed), for: .touchUpInside)

        selectionStyle = UITableViewCell.SelectionStyle.none
        separatorInset = UIEdgeInsets.zero
    }

    required init?(coder: NSCoder) {
        os_log("RollershutterUITableViewCell initWithCoder", log: .viewCycle, type: .info)
        super.init(coder: coder)
        initialize()
    }

    override init (style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        os_log("RollershutterUITableViewCell initWithStyle", log: .viewCycle, type: .info)
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        initialize()
    }

    override func displayWidget() {
        customTextLabel?.text = widget.labelText()
    }

    @objc func upButtonPressed() {
        os_log("up button pressed", log: .viewCycle, type: .info)
        widget.sendCommand("UP")

    }

    @objc func stopButtonPressed() {
        os_log("stop button pressed", log: .viewCycle, type: .info)
        widget.sendCommand("STOP")
    }

    @objc func downButtonPressed() {
        os_log("down button pressed", log: .viewCycle, type: .info)
        widget.sendCommand("DOWN")
    }
}
