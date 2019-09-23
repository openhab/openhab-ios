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

        selectionStyle = .none
        separatorInset = .zero
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        separatorInset = .zero
    }

    override func displayWidget() {
        textLabel?.textColor = .darkGray
        textLabel?.font = .preferredFont(forTextStyle: .callout)
        textLabel?.text = widget.label.uppercased()
        contentView.sizeToFit()
    }
}
