//
//  ColorUtil.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 17.02.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import UIKit

enum Colors {
     static let hightlightStrokeColor: UIColor = .black
}

func namedColor(toHexString namedColor: String) -> String? {
    let namedColors = ["maroon": "#800000", "red": "#ff0000", "orange": "#ffa500", "olive": "#808000", "yellow": "#ffff00", "purple": "#800080", "fuchsia": "#ff00ff", "white": "#ffffff", "lime": "#00ff00", "green": "#008000", "navy": "#000080", "blue": "#0000ff", "teal": "#008080", "aqua": "#00ffff", "black": "#000000", "silver": "#c0c0c0", "gray": "#808080"]
    return namedColors[namedColor.lowercased()]
}

func color(fromHexString hexString: String?) -> UIColor? {
    var cString: String = hexString?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ??  "x800000"
    if !cString.hasPrefix("#"), let namedColor = namedColor(toHexString: cString) {
        cString = namedColor
    }
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
