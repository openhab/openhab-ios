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
    private var namedColors: [AnyHashable: Any] = [:]

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

                disclosureConstraints = NSLayoutConstraint.constraints(withVisualFormat: formatString, options: [], metrics: nil, views: views as [String : Any])
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

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        selectionStyle = .none
        separatorInset = .zero
        namedColors = ["maroon": "#800000", "red": "#ff0000", "orange": "#ffa500", "olive": "#808000", "yellow": "#ffff00", "purple": "#800080", "fuchsia": "#ff00ff", "white": "#ffffff", "lime": "#00ff00", "green": "#008000", "navy": "#000080", "blue": "#0000ff", "teal": "#008080", "aqua": "#00ffff", "black": "#000000", "silver": "#c0c0c0", "gray": "#808080"]
    }

    override init (style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        separatorInset = .zero
        namedColors = ["maroon": "#800000", "red": "#ff0000", "orange": "#ffa500", "olive": "#808000", "yellow": "#ffff00", "purple": "#800080", "fuchsia": "#ff00ff", "white": "#ffffff", "lime": "#00ff00", "green": "#008000", "navy": "#000080", "blue": "#0000ff", "teal": "#008080", "aqua": "#00ffff", "black": "#000000", "silver": "#c0c0c0", "gray": "#808080"]

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

    func namedColor(toHexString namedColor: String?) -> String? {
        return namedColors[namedColor?.lowercased() ?? ""] as? String
    }

    func color(fromHexString hexString: String?) -> UIColor? {
        var cString: String = hexString?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ??  "x800000"

        if cString.hasPrefix("#") {
            cString.remove(at: cString.startIndex)
        }

        if (cString.count) != 6 {
            return UIColor.gray
        }

        var rgbValue: UInt32 = 0
        Scanner(string: cString).scanHexInt32(&rgbValue)

        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }

    static var identifier: String {
        return String(describing: self)
    }

}
