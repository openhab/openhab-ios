// Copyright (c) 2010-2019 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import DynamicButton
import os.log
import UIKit

class RollershutterUITableViewCell: GenericUITableViewCell {
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    @IBOutlet private var downButton: DynamicButton!
    @IBOutlet private var stopButton: DynamicButton!
    @IBOutlet private var upButton: DynamicButton!
    @IBOutlet private var customDetailText: UILabel!

    override func initialize() {
        selectionStyle = .none
        separatorInset = .zero
    }

    required init?(coder: NSCoder) {
        os_log("RollershutterUITableViewCell initWithCoder", log: .viewCycle, type: .info)
        super.init(coder: coder)
        initialize()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
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
        upButton?.highlightStokeColor = Colors.hightlightStrokeColor
        stopButton?.highlightStokeColor = Colors.hightlightStrokeColor
    }

    @objc
    func upButtonPressed() {
        os_log("up button pressed", log: .viewCycle, type: .info)
        widget.sendCommand("UP")
        feedbackGenerator.impactOccurred()
    }

    @objc
    func stopButtonPressed() {
        os_log("stop button pressed", log: .viewCycle, type: .info)
        widget.sendCommand("STOP")
        feedbackGenerator.impactOccurred()
    }

    @objc
    func downButtonPressed() {
        os_log("down button pressed", log: .viewCycle, type: .info)
        widget.sendCommand("DOWN")
        feedbackGenerator.impactOccurred()
    }
}

// inspired by: Selectors in swift: A better approach using extensions
// https://medium.com/@abhimuralidharan/selectors-in-swift-a-better-approach-using-extensions-aa6b0416e850
private extension Selector {
    static let upButtonPressed = #selector(RollershutterUITableViewCell.upButtonPressed)
    static let stopButtonPressed = #selector(RollershutterUITableViewCell.stopButtonPressed)
    static let downButtonPressed = #selector(RollershutterUITableViewCell.downButtonPressed)
}
