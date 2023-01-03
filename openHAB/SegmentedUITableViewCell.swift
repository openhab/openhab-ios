// Copyright (c) 2010-2023 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import os.log
import UIKit

class SegmentedUITableViewCell: GenericUITableViewCell {
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    // @IBOutlet private var customTextLabel: UILabel!
    @IBOutlet private var widgetSegmentControl: UISegmentedControl!

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        selectionStyle = .none
        separatorInset = .zero
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        separatorInset = .zero
    }

    override func displayWidget() {
        customTextLabel?.text = widget.labelText
        customDetailTextLabel?.text = widget.labelValue ?? ""

        widgetSegmentControl.apportionsSegmentWidthsByContent = true
        widgetSegmentControl.removeAllSegments()
        widgetSegmentControl.apportionsSegmentWidthsByContent = true

        for (index, mapping) in (widget?.mappingsOrItemOptions ?? []).enumerated() {
            widgetSegmentControl.insertSegment(withTitle: mapping.label, at: index, animated: false)
        }

        widgetSegmentControl.isMomentary = widget.mappingsOrItemOptions.count == 1 || widget.item?.state == "NULL"
        widgetSegmentControl.selectedSegmentIndex = widgetSegmentControl.isMomentary ? -1 : Int(widget.mappingIndex(byCommand: widget.item?.state) ?? -1)
        widgetSegmentControl.addTarget(self, action: #selector(SegmentedUITableViewCell.pickOne(_:)), for: .valueChanged)
    }

    @objc
    func pickOne(_ sender: Any?) {
        guard let segmentedControl = sender as? UISegmentedControl, let mapping = widget.mappingsOrItemOptions[safe: segmentedControl.selectedSegmentIndex] else {
            return
        }

        os_log("Segment pressed %d", log: .default, type: .info, segmentedControl.selectedSegmentIndex)
        widget.sendCommand(mapping.command)
        feedbackGenerator.impactOccurred()
    }
}
