//
//  SelectionUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 27/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

class SelectionUITableViewCell: GenericUITableViewCell {
    override var widget: OpenHABWidget! {
        get {
            return super.widget
        }
        set(widget) {
            super.widget = widget
            accessoryType = .disclosureIndicator
            selectionStyle = .blue
        }
    }

    override func displayWidget() {
        super.customTextLabel?.text = widget.labelText
        let selectedMapping = widget.mappingIndex(byCommand: widget.item?.state)
        if let selectedMapping = selectedMapping {
            if let widgetMapping = widget?.mappings[Int(selectedMapping)] {
                customDetailTextLabel?.text = widgetMapping.label
            }
        } else {
            customDetailTextLabel?.text = ""
        }
    }
}
