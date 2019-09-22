//
//  GenericUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 15/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import Kingfisher
import UIKit

protocol GenericCellCacheProtocol: UITableViewCell {
    func invalidateCache()
}

class GenericUITableViewCell: UITableViewCell {

    private var _widget: OpenHABWidget!
    var widget: OpenHABWidget! {
        get {
            return _widget
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

            if _widget.labelcolor != "" {
                if let color = color(fromHexString: self.widget?.labelcolor) {
                    customTextLabel?.textColor = color
                }
            } else {
                if #available(iOS 13.0, *) {
                    customTextLabel?.textColor = UIColor.label
                } else {
                    customTextLabel?.textColor = UIColor.black
                }
            }
            if _widget.valuecolor != "" {
                if let color = color(fromHexString: self.widget?.valuecolor) {
                    customDetailTextLabel?.textColor = color
                }
            } else {
                if #available(iOS 13.0, *) {
                    customDetailTextLabel?.textColor = UIColor.secondaryLabel
                } else {
                    customDetailTextLabel?.textColor = UIColor.lightGray
                }
            }
        }
    }

    @IBOutlet weak var customTextLabel: UILabel!
    @IBOutlet weak var customDetailTextLabel: UILabel!
    @IBOutlet weak var customDetailTextLabelConstraint: NSLayoutConstraint!

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }

    override init (style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
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
                // If accessory is enabled, set detailTextLabel (widget value) constraint 0px to the right
                customDetailTextLabelConstraint.constant = 0.0
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
