//  Converted to Swift 4 by Swiftify v4.2.28993 - https://objectivec2swift.com/
//
//  GenericUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 15/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

import UIKit

class GenericUITableViewCell: UITableViewCell {
    private var namedColors: [AnyHashable : Any] = [:]

    func displayWidget() {
        textLabel?.text = widget?.labelText()
        if widget?.labelValue() != nil {
            detailTextLabel?.text = widget?.labelValue()
        } else {
            detailTextLabel?.text = nil
        }
        detailTextLabel?.sizeToFit()
        // Clean any detailTextLabel constraints we set before, or they will start to interfere with new ones because of UITableViewCell caching
        if disclosureConstraints.count != 0 {
            if let disclosureConstraints = disclosureConstraints as? [NSLayoutConstraint] {
                removeConstraints(disclosureConstraints)
            }
            disclosureConstraints = []
        }
        if accessoryType == .none {
            // If accessory is disabled, set detailTextLabel (widget value) constraing 20px to the right for padding to the right side of table view
//            if let detailTextLabelC = detailTextLabel {
//                disclosureConstraints = NSLayoutConstraint.constraints(withVisualFormat: "[detailTextLabel]-20.0-|", options: [], metrics: nil, views: NSDictionaryOfVariableBindings(detailTextLabelC) )
//                if let disclosureConstraints = disclosureConstraints as? [NSLayoutConstraint] {
//                    addConstraints(disclosureConstraints)
//                }
//            }
        } else {
            // If accessory is enabled, set detailTextLabel (widget value) constraint 0px to the right
//            if detailTextLabel != nil {
//                disclosureConstraints = NSLayoutConstraint.constraints(withVisualFormat: "[detailTextLabel]|", options: [], metrics: nil, views: NSDictionaryOfVariableBindings(detailTextLabel))
//                if let disclosureConstraints = disclosureConstraints as? [NSLayoutConstraint] {
//                    addConstraints(disclosureConstraints)
//                }
//            }
        }
    }


    private var _widget: OpenHABWidget?
    var widget: OpenHABWidget? {
        get {
            return _widget
        }
        set(widget) {
            self.widget = widget

            if self.widget?.linkedPage != nil {
                accessoryType = .disclosureIndicator
                selectionStyle = .blue
                //        self.userInteractionEnabled = YES;
            } else {
                accessoryType = .none
                selectionStyle = .none
                //        self.userInteractionEnabled = NO;
            }
    
            if let color = color(fromHexString: self.widget?.labelcolor) {
                    textLabel?.textColor = color
                
            } else {
                textLabel?.textColor = UIColor.black
            }
            if self.widget?.valuecolor != nil {
                if let color = color(fromHexString: self.widget?.valuecolor) {
                    detailTextLabel?.textColor = color
                }
            } else {
                detailTextLabel?.textColor = UIColor.lightGray
            }
        }
    }
//    var textLabel: UILabel?
//    var detailTextLabel: UILabel?
    var disclosureConstraints: [Any] = []

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
//        textLabel = viewWithTag(101) as? UILabel
//        detailTextLabel = viewWithTag(100) as? UILabel
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
        var cString:String = hexString?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ??  "x800000"
        
        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }
        
        if ((cString.count) != 6) {
            return UIColor.gray
        }
        
        var rgbValue:UInt32 = 0
        Scanner(string: cString).scanHexInt32(&rgbValue)
        
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }

//    func color(fromHexString hexString: String?) -> UIColor? {
//        var colorString = hexString
//        if !(hexString?.hasPrefix("#") ?? false) {
//            let namedColor = self.namedColor(toHexString: hexString)
//            if namedColor != nil {
//                colorString = namedColor
//            }
//        }
//
//        var rgbValue: UInt = 0
//        let scanner = Scanner(string: colorString ?? "")
//        scanner.scanLocation = 1 // bypass '#' character
//        scanner.scanHexInt32(&rgbValue)
//        return UIColor(red: Double(((Int(rgbValue) & 0xff0000) >> 16)) / 255.0, green: Double(((Int(rgbValue) & 0xff00) >> 8)) / 255.0, blue: Double((Int(rgbValue) & 0xff)) / 255.0, alpha: 1.0)
//    }
}
