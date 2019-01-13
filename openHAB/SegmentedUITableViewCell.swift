//
//  SegmentedUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 17/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

class SegmentedUITableViewCell: GenericUITableViewCell {

    //@IBOutlet weak var customTextLabel: UILabel!
    @IBOutlet weak var widgetSegmentControl: UISegmentedControl!
    required init?(coder: NSCoder) {
        super.init(coder: coder)

        selectionStyle = UITableViewCell.SelectionStyle.none
        separatorInset = UIEdgeInsets.zero

    }

    override init (style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = UITableViewCell.SelectionStyle.none
        separatorInset = UIEdgeInsets.zero

    }

    override func displayWidget() {
        self.customTextLabel?.text = widget.labelText()
        widgetSegmentControl?.apportionsSegmentWidthsByContent = true
        widgetSegmentControl?.removeAllSegments()
        widgetSegmentControl?.apportionsSegmentWidthsByContent = true

        for mapping: OpenHABWidgetMapping? in widget?.mappings as? [OpenHABWidgetMapping?] ?? [] {
            if let mapping = mapping {
                widgetSegmentControl?.insertSegment(withTitle: mapping.label, at: widget.mappings.index(of: mapping), animated: false)
            }
        }
        widgetSegmentControl?.selectedSegmentIndex = Int(widget.mappingIndex(byCommand: widget.item.state))
        widgetSegmentControl?.addTarget(self, action: #selector(SegmentedUITableViewCell.pickOne(_:)), for: .valueChanged)
    }

    @objc func pickOne(_ sender: Any?) {
        let segmentedControl = sender as? UISegmentedControl
        print(String(format: "Segment pressed %ld", Int(segmentedControl?.selectedSegmentIndex ?? 0)))
        if widget.mappings != nil {
            let mapping = widget.mappings[segmentedControl?.selectedSegmentIndex ?? 0] as? OpenHABWidgetMapping
            widget.sendCommand(mapping?.command)
        }
    }
}
