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

class RollershutterCell: GenericUITableViewCell {
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    @IBOutlet private var upButton: UIButton!
    @IBOutlet private var stopButton: UIButton!
    @IBOutlet private var downButton: UIButton!
    @IBOutlet private var customDetailText: UILabel!

    required init?(coder: NSCoder) {
        os_log("RollershutterCell initWithCoder", log: .viewCycle, type: .info)
        super.init(coder: coder)
        initialize()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        os_log("RollershutterCell initWithStyle", log: .viewCycle, type: .info)
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        initialize()
    }

    override func initialize() {
        selectionStyle = .none
        separatorInset = .zero
    }

    override func displayWidget() {
        customTextLabel?.text = widget.labelText
        customDetailText?.text = widget.labelValue ?? ""
        upButton?.addTarget(self, action: .upButtonPressed, for: .touchUpInside)
        stopButton?.addTarget(self, action: .stopButtonPressed, for: .touchUpInside)
        downButton?.addTarget(self, action: .downButtonPressed, for: .touchUpInside)
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
    static let upButtonPressed = #selector(RollershutterCell.upButtonPressed)
    static let stopButtonPressed = #selector(RollershutterCell.stopButtonPressed)
    static let downButtonPressed = #selector(RollershutterCell.downButtonPressed)
}
