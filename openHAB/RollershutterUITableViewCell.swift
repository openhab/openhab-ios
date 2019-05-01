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

// inspired by: Selectors in swift: A better approach using extensions
// https://medium.com/@abhimuralidharan/selectors-in-swift-a-better-approach-using-extensions-aa6b0416e850
fileprivate extension Selector {
    static let upButtonPressed = #selector(RollershutterUITableViewCell.upButtonPressed)
    static let stopButtonPressed = #selector(RollershutterUITableViewCell.stopButtonPressed)
    static let downButtonPressed = #selector(RollershutterUITableViewCell.downButtonPressed)
}

class RollershutterUITableViewCell: GenericUITableViewCell {

    @IBOutlet weak var downButton: UICircleButton!
    @IBOutlet weak var stopButton: UICircleButton!
    @IBOutlet weak var upButton: UICircleButton!

    override func initialize() {
        selectionStyle = .none
        separatorInset = .zero
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

        self.upButton?.setTitle("▲", for: .normal)
        self.stopButton?.setTitle("■", for: .normal)
        downButton?.setTitle("▼", for: .normal)

        upButton?.addTarget(self, action: .upButtonPressed, for: .touchUpInside)
        stopButton?.addTarget(self, action: .stopButtonPressed, for: .touchUpInside)
        downButton?.addTarget(self, action: .downButtonPressed, for: .touchUpInside)
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
