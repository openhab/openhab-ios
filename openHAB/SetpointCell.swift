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

class SetpointCell: GenericUITableViewCell {
    private let setpointService: SetPointService

    @IBOutlet private var downButton: UIButton!
    @IBOutlet private var upButton: UIButton!
    required init?(coder: NSCoder) {
        setpointService = SetPointService()

        super.init(coder: coder)

        selectionStyle = .none
        separatorInset = .zero
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        setpointService = SetPointService()
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }

    override func displayWidget() {
        downButton.addTarget(self, action: #selector(SetpointCell.decreaseValue), for: .touchUpInside)
        upButton.addTarget(self, action: #selector(SetpointCell.increaseValue), for: .touchUpInside)

        super.displayWidget()
    }

    private func handleUpDown(down: Bool) {
        var numberState = widget?.stateValueAsNumberState
        let currentValue = numberState?.value ?? widget.minValue

        let limitedNewValue = setpointService.calculateNewValue(
            currentValue: currentValue,
            step: widget.step,
            minValue: widget.minValue,
            maxValue: widget.maxValue,
            isDecreasing: down
        )

        guard limitedNewValue != currentValue else {
            // nothing to update, skip sending value
            return
        }

        if numberState != nil {
            numberState?.value = limitedNewValue
        } else {
            numberState = NumberState(value: limitedNewValue)
        }

        widget.sendItemUpdate(state: numberState)
    }

    @objc
    func decreaseValue(_ sender: Any?) {
        handleUpDown(down: true)
    }

    @objc
    func increaseValue(_ sender: Any?) {
        handleUpDown(down: false)
    }
}
