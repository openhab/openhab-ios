//  Converted to Swift 4 by Swiftify v4.2.28993 - https://objectivec2swift.com/
//
//  SelectionUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 27/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

class SelectionUITableViewCell: GenericUITableViewCell {
    func setWidget(_ widget: OpenHABWidget?) {
        super.widget = widget
        accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
        selectionStyle = UITableViewCell.SelectionStyle.blue
    }

    override func displayWidget() {
        textLabel.text = widget.labelText()
        let selectedMapping = widget.mappingIndex(byCommand: widget.item.state)
        if selectedMapping != NSNotFound {
            if let widgetMapping = widget?.mappings[Int(selectedMapping)] as? OpenHABWidgetMapping {
                detailTextLabel.text = widgetMapping.label
            }
        }

    }
}
