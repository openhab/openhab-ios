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

import Kingfisher
import OpenHABCore
import UIKit

protocol GenericCellCacheProtocol: UITableViewCell {
    func invalidateCache()
}

class GenericUITableViewCell: UITableViewCell {
    private var _widget: OpenHABWidget!
    var widget: OpenHABWidget! {
        get {
            _widget
        }
        set(widget) {
            _widget = widget

            if _widget.linkedPage != nil {
                accessoryType = .disclosureIndicator
                selectionStyle = .blue
                //        self.userInteractionEnabled = YES;
            } else {
                accessoryType = .none
                selectionStyle = .none
                //        self.userInteractionEnabled = NO;
            }

            customTextLabel?.textColor = !(_widget.labelcolor.isEmpty) ? UIColor(fromString: _widget.labelcolor) : .ohLabel
            customDetailTextLabel?.textColor = !(_widget.valuecolor.isEmpty) ? UIColor(fromString: _widget.valuecolor) : .ohSecondaryLabel
        }
    }

    @IBOutlet private(set) var customTextLabel: UILabel!
    @IBOutlet private(set) var customDetailTextLabel: UILabel!
    @IBOutlet private(set) var customDetailTextLabelConstraint: NSLayoutConstraint!

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        initialize()
    }

    func initialize() {
        selectionStyle = .none
        separatorInset = .zero
    }

    // This is to fix possible different sizes of user icons - we fix size and position of UITableViewCell icons
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView?.frame = CGRect(x: 13, y: 5, width: 32, height: 32)
    }

    func displayWidget() {
        customTextLabel?.text = widget?.labelText
        customDetailTextLabel?.text = widget?.labelValue ?? ""
        customDetailTextLabel?.sizeToFit()

        if customDetailTextLabel != nil, customDetailTextLabelConstraint != nil {
            if accessoryType == .none {
                // If accessory is disabled, set detailTextLabel (widget value) constraint 20px to the right for padding to the right side of table view
                customDetailTextLabelConstraint.constant = 20.0
            } else {
                // If accessory is enabled, set detailTextLabel (widget value) constraint 5px to the right
                customDetailTextLabelConstraint.constant = 5.0
            }
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView?.kf.cancelDownloadTask()
        imageView?.image = nil
    }
}
