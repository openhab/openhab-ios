//
//  RollershutterUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 27/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import DynamicButton
import os.log

// inspired by: Selectors in swift: A better approach using extensions
// https://medium.com/@abhimuralidharan/selectors-in-swift-a-better-approach-using-extensions-aa6b0416e850
fileprivate extension Selector {
    static let upButtonPressed = #selector(RollershutterUITableViewCell.upButtonPressed)
    static let stopButtonPressed = #selector(RollershutterUITableViewCell.stopButtonPressed)
    static let downButtonPressed = #selector(RollershutterUITableViewCell.downButtonPressed)
}

class RollershutterUITableViewCell: GenericUITableViewCell {

    @IBOutlet weak var downButton: DynamicButton!
    @IBOutlet weak var stopButton: DynamicButton!
    @IBOutlet weak var upButton: DynamicButton!

    @IBOutlet weak var customDetailText: UILabel!

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
        customTextLabel?.text = widget.labelText
        customDetailText?.text = widget.labelValue ?? ""        
        upButton?.setStyle(.caretUp, animated: true)
        stopButton?.setStyle(.stop, animated: true)
        downButton?.setStyle(.caretDown, animated: true)
        upButton?.addTarget(self, action: .upButtonPressed, for: .touchUpInside)
        stopButton?.addTarget(self, action: .stopButtonPressed, for: .touchUpInside)
        downButton?.addTarget(self, action: .downButtonPressed, for: .touchUpInside)
        downButton?.highlightStokeColor = Colors.hightlightStrokeColor
        upButton?.highlightStokeColor =  Colors.hightlightStrokeColor
        stopButton?.highlightStokeColor =  Colors.hightlightStrokeColor
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
