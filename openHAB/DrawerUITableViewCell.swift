// Copyright (c) 2010-2021 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import os.log
import UIKit

class DrawerUITableViewCell: UITableViewCell {
    @IBOutlet private(set) var customTextLabel: UILabel!
    @IBOutlet private(set) var customImageView: UIImageView!

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
