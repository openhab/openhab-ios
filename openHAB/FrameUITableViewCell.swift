//  Converted to Swift 4 by Swiftify v4.2.28993 - https://objectivec2swift.com/
//
//  FrameUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 15/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

import UIKit

class FrameUITableViewCell: GenericUITableViewCell {

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        textLabel = viewWithTag(100) as? UILabel
        selectionStyle = UITableViewCell.SelectionStyle.none
        separatorInset = UIEdgeInsets.zero
    
    }

    override func displayWidget() {
        textLabel?.text = widget.label.uppercased()
        contentView.sizeToFit()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}
