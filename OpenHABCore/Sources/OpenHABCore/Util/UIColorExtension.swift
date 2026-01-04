// Copyright (c) 2010-2026 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import SwiftUI
import UIKit

public enum OHInterfaceStyle: Int {
    case light, dark

    public static var current: OHInterfaceStyle {
        #if os(watchOS)
        return .dark
        #elseif os(iOS)
        if UITraitCollection.current.userInterfaceStyle == .dark {
            return .dark
        } else {
            return .light
        }
        #else
        return .light
        #endif
    }
}

public extension UIColor {
    // system colors
    class var ohLabel: UIColor {
        #if os(iOS)
        if #available(iOS 13.0, *) {
            return .label
        }
        #endif
        return .black
    }

    class var ohSecondaryLabel: UIColor {
        #if os(iOS)
        if #available(iOS 13.0, *) {
            return .secondaryLabel
        }
        #endif
        return .lightGray
    }

    class var ohSystemBackground: UIColor {
        #if os(iOS)
        if #available(iOS 13.0, *) {
            return .systemBackground
        }
        #endif
        return .white
    }

    class var ohSystemGroupedBackground: UIColor {
        #if os(iOS)
        if #available(iOS 13.0, *) {
            return .systemGroupedBackground
        } else {
            return .groupTableViewBackground
        }
        #elseif os(watchOS)
        return .black
        #else
        return .white
        #endif
    }

    class var ohSecondarySystemGroupedBackground: UIColor {
        #if os(iOS)
        if #available(iOS 13.0, *) {
            return .secondarySystemGroupedBackground
        }
        #endif

        return .white
    }

    // standard colors
    class var ohMaroon: UIColor {
        OHInterfaceStyle.current == .light ? UIColor(hex: "#800000") : UIColor(hex: "#800000")
    }

    class var ohRed: UIColor {
        OHInterfaceStyle.current == .light ? UIColor(hex: "#ff0000") : UIColor(hex: "#ff0000")
    }

    class var ohOrange: UIColor {
        OHInterfaceStyle.current == .light ? UIColor(hex: "#ffa500") : UIColor(hex: "#ffa500")
    }

    class var ohOlive: UIColor {
        OHInterfaceStyle.current == .light ? UIColor(hex: "#808000") : UIColor(hex: "#808000")
    }

    class var ohYellow: UIColor {
        OHInterfaceStyle.current == .light ? UIColor(hex: "#ffff00") : UIColor(hex: "#ffff00")
    }

    class var ohPurple: UIColor {
        OHInterfaceStyle.current == .light ? UIColor(hex: "#800080") : UIColor(hex: "#800080")
    }

    class var ohFuchsia: UIColor {
        OHInterfaceStyle.current == .light ? UIColor(hex: "#ff00ff") : UIColor(hex: "#ff00ff")
    }

    class var ohWhite: UIColor {
        OHInterfaceStyle.current == .light ? .white : .black
    }

    class var ohLime: UIColor {
        OHInterfaceStyle.current == .light ? UIColor(hex: "#00ff00") : UIColor(hex: "#00ff00")
    }

    class var ohGreen: UIColor {
        OHInterfaceStyle.current == .light ? UIColor(hex: "#008000") : UIColor(hex: "#008000")
    }

    class var ohNavy: UIColor {
        OHInterfaceStyle.current == .light ? UIColor(hex: "#000080") : UIColor(hex: "#000080")
    }

    class var ohBlue: UIColor {
        OHInterfaceStyle.current == .light ? UIColor(hex: "#0000ff") : UIColor(hex: "#0000ff")
    }

    class var ohTeal: UIColor {
        OHInterfaceStyle.current == .light ? UIColor(hex: "#008080") : UIColor(hex: "#008080")
    }

    class var ohAqua: UIColor {
        OHInterfaceStyle.current == .light ? UIColor(hex: "#00ffff") : UIColor(hex: "#00ffff")
    }

    class var ohBlack: UIColor {
        OHInterfaceStyle.current == .light ? .black : .white
    }

    class var ohSilver: UIColor {
        OHInterfaceStyle.current == .light ? UIColor(hex: "#c0c0c0") : UIColor(hex: "#c0c0c0")
    }

    class var ohGray: UIColor {
        OHInterfaceStyle.current == .light ? UIColor(hex: "#808080") : UIColor(hex: "#808080")
    }

    class var ohPrimary: UIColor {
        UIColor(.primary)
    }

    class var ohSecondary: UIColor {
        UIColor(.secondary)
    }
}

public extension UIColor {
    var hexString: String? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }

        let r = UInt8(round(red * 255))
        let g = UInt8(round(green * 255))
        let b = UInt8(round(blue * 255))
        let a = UInt8(round(alpha * 255))

        func toHex(_ value: UInt8) -> String {
            let hex = String(value, radix: 16, uppercase: true)
            return hex.count == 1 ? "0" + hex : hex
        }

        let components = [r, g, b] + (a == 255 ? [] : [a])
        return components.map(toHex).joined()
    }

    /// Initializes a UIColor from a string, supporting named colors and hex codes.
    /// Falls back to gray if the input is invalid.
    convenience init(fromString string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let namedColors: [String: UIColor] = [
            "maroon": .ohMaroon,
            "red": .ohRed,
            "orange": .ohOrange,
            "olive": .ohOlive,
            "yellow": .ohYellow,
            "purple": .ohPurple,
            "fuchsia": .ohFuchsia,
            "white": .ohWhite,
            "lime": .ohLime,
            "green": .ohGreen,
            "navy": .ohNavy,
            "blue": .ohBlue,
            "teal": .ohTeal,
            "aqua": .ohAqua,
            "black": .ohBlack,
            "silver": .ohSilver,
            "gray": .ohGray,
            "primary": .ohPrimary,
            "secondary": .ohSecondary
        ]
        if let color = namedColors[trimmed] {
            self.init(cgColor: color.cgColor)
            return
        }
        // Try hex
        let hexColor = UIColor(hex: string)
        self.init(cgColor: hexColor.cgColor)
    }

    convenience init(hex: String) {
        guard hex.count >= 6 else {
            self.init(cgColor: UIColor.gray.cgColor)
            return
        }

        let hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let scanner = Scanner(string: hexString)
        scanner.charactersToBeSkipped = CharacterSet(charactersIn: "#")

        var color: UInt64 = 0
        scanner.scanHexInt64(&color)

        let mask = 0x000000FF
        let aRed = Int(color >> 16) & mask
        let aGreen = Int(color >> 8) & mask
        let aBlue = Int(color) & mask

        let red = CGFloat(aRed) / 255.0
        let green = CGFloat(aGreen) / 255.0
        let blue = CGFloat(aBlue) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: 1)
    }

    // Inspired by https://cocoacasts.com/from-hex-to-uicolor-and-back-in-swift

    // MARK: - From UIColor to String

    func toHex(alpha: Bool = false) -> String? {
        guard let components = cgColor.components, components.count >= 3 else {
            return nil
        }

        let red = Float(components[0])
        let green = Float(components[1])
        let blue = Float(components[2])
        var a = Float(1.0)

        if components.count >= 4 {
            a = Float(components[3])
        }

        if alpha {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(red * 255), lroundf(green * 255), lroundf(blue * 255), lroundf(a * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(red * 255), lroundf(green * 255), lroundf(blue * 255))
        }
    }
}
