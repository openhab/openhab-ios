//  Converted to Swift 4 by Swiftify v4.2.28993 - https://objectivec2swift.com/
//
//  SegmentedUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 17/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

class SegmentedUITableViewCell: GenericUITableViewCell {
    var widgetSegmentedControl: UISegmentedControl?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        widgetSegmentedControl = viewWithTag(500) as? UISegmentedControl
        selectionStyle = UITableViewCell.SelectionStyle.none
        separatorInset = UIEdgeInsets.zero
    
    }

    override func displayWidget() {
        textLabel?.text = widget.labelText()
        widgetSegmentedControl?.apportionsSegmentWidthsByContent = true
        widgetSegmentedControl?.removeAllSegments()
        widgetSegmentedControl?.apportionsSegmentWidthsByContent = true
        
        for mapping: OpenHABWidgetMapping? in widget?.mappings as? [OpenHABWidgetMapping?] ?? []  {
            if let mapping = mapping {
                widgetSegmentedControl?.insertSegment(withTitle: mapping.label, at: widget.mappings.index(of: mapping), animated: false)
            }
        }
        widgetSegmentedControl?.selectedSegmentIndex = Int(widget.mappingIndex(byCommand: widget.item.state))
        widgetSegmentedControl?.addTarget(self, action: #selector(SegmentedUITableViewCell.pickOne(_:)), for: .valueChanged)
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
