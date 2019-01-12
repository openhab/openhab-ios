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
    func setWidget(_ widget: OpenHABWidget?) {
        super.widget = widget
        accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
        selectionStyle = UITableViewCell.SelectionStyle.blue
    }

    override func displayWidget() {
        customTextLabel?.text = widget.labelText()
        let selectedMapping = widget.mappingIndex(byCommand: widget.item.state)
        if selectedMapping != NSNotFound {
            if let widgetMapping = widget?.mappings[Int(selectedMapping)] as? OpenHABWidgetMapping {
                detailTextLabel?.text = widgetMapping.label
            }
        }

    }
}
