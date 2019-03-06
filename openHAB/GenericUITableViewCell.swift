//
//  GenericUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 15/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import UIKit

class GenericUITableViewCell: UITableViewCell {

    @objc func displayWidget() {
        customTextLabel?.text = widget?.labelText()
        if widget?.labelValue() != nil {
            customDetailTextLabel?.text = widget?.labelValue()
        } else {
            customDetailTextLabel?.text = ""
        }
        customDetailTextLabel?.sizeToFit()
        // Clean any detailTextLabel constraints we set before, or they will start to interfere with new ones because of UITableViewCell caching
        if !disclosureConstraints.isEmpty {
            removeConstraints(disclosureConstraints)
            disclosureConstraints = []
        }
        if accessoryType == .none {
            // If accessory is disabled, set detailTextLabel (widget value) constraint 20px to the right for padding to the right side of table view
            if customDetailTextLabel != nil {
                let views = ["customDetailTextLabel": customDetailTextLabel]
                let formatString = "[customDetailTextLabel]-20.0-|"

                disclosureConstraints = NSLayoutConstraint.constraints(withVisualFormat: formatString, options: [], metrics: nil, views: views as [String: Any])
                addConstraints(disclosureConstraints)
            }
        } else {
            // If accessory is enabled, set detailTextLabel (widget value) constraint 0px to the right
            if customDetailTextLabel != nil {
                let views = ["customDetailTextLabel": customDetailTextLabel]
                let formatString = "[customDetailTextLabel]|"

                disclosureConstraints = NSLayoutConstraint.constraints(withVisualFormat: formatString, options: [], metrics: nil, views: views as [String: Any])
                addConstraints(disclosureConstraints)
            }
        }
    }

    private var _widget: OpenHABWidget!
    @objc var widget: OpenHABWidget! {
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
                customTextLabel?.textColor = UIColor.black
            }
            if _widget.valuecolor != "" {
                if let color = color(fromHexString: self.widget?.valuecolor) {
                    customDetailTextLabel?.textColor = color
                }
            } else {
                customDetailTextLabel?.textColor = UIColor.lightGray
            }
        }
    }

    @IBOutlet weak var customTextLabel: UILabel!
    @IBOutlet weak var customDetailTextLabel: UILabel!

    var disclosureConstraints: [NSLayoutConstraint] = []

    func initialize() {
        selectionStyle = .none
        separatorInset = .zero
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }

    override init (style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        initialize()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    /*
     * This setter must be called via `super.widget`
     * when it gets overriden inside a subclass.
     */
    // This is to fix possible different sizes of user icons - we fix size and position of UITableViewCell icons
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView?.frame = CGRect(x: 13, y: 5, width: 32, height: 32)
    }

}
