//
//  FrameUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 15/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import UIKit

class FrameUITableViewCell: GenericUITableViewCell {

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
  //      textLabel = viewWithTag(100) as? UILabel
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
