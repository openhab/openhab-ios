//  Converted to Swift 4 by Swiftify v4.2.28993 - https://objectivec2swift.com/
//
//  DrawerUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 02/06/16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//

import UIKit
import os.log

class DrawerUITableViewCell: UITableViewCell {
    //var textLabel: UILabel?

    @IBOutlet weak var customTextLabel: UILabel!
    @IBOutlet weak var customImageView: UIImageView!

    required init?(coder: NSCoder) {
        os_log("DrawerUITableViewCell initWithCoder", log: .viewCycle, type: .info)
        super.init(coder: coder)

        separatorInset = .zero

    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    // This is to fix possible different sizes of user icons - we fix size and position of UITableViewCell icons
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView?.frame = CGRect(x: 14, y: 6, width: 30, height: 30)
    }
}
