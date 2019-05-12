//
//  NotificationTableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 02/06/16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import os.log
import UIKit

class NotificationTableViewCell: UITableViewCell {

    @IBOutlet weak var customTextLabel: UILabel!
    @IBOutlet weak var customDetailTextLabel: UILabel!

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
