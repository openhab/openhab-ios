//
//  SegmentedUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 17/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//
import os.log

class SegmentedUITableViewCell: GenericUITableViewCell {

    //@IBOutlet weak var customTextLabel: UILabel!
    @IBOutlet weak var widgetSegmentControl: UISegmentedControl!
    required init?(coder: NSCoder) {
        super.init(coder: coder)

        selectionStyle = .none
        separatorInset = .zero

    }

    override init (style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        separatorInset = .zero

    }

    override func displayWidget() {
        self.customTextLabel?.text = widget.labelText()
        widgetSegmentControl?.apportionsSegmentWidthsByContent = true
        widgetSegmentControl?.removeAllSegments()
        widgetSegmentControl?.apportionsSegmentWidthsByContent = true

        for mapping in widget?.mappings ?? [] {
                widgetSegmentControl?.insertSegment(withTitle: mapping.label, at: widget.mappings.firstIndex(of: mapping)!, animated: false)
        }

        widgetSegmentControl?.selectedSegmentIndex = Int(widget.mappingIndex(byCommand: widget.item?.state))
        widgetSegmentControl?.addTarget(self, action: #selector(SegmentedUITableViewCell.pickOne(_:)), for: .valueChanged)
    }

    @objc func pickOne(_ sender: Any?) {
        let segmentedControl = sender as? UISegmentedControl
        os_log("Segment pressed %d", log: .default, type: .info, Int(segmentedControl?.selectedSegmentIndex ?? 0))

        let mapping = widget.mappings[segmentedControl?.selectedSegmentIndex ?? 0]
        widget.sendCommand(mapping.command)
    }
}
