// Copyright (c) 2010-2020 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import UIKit

public enum OHInterfaceStyle: Int {
    case light, dark

    public static var current: OHInterfaceStyle {
        #if os(iOS)
        if #available(iOS 13.0, *) {
            if UITraitCollection.current.userInterfaceStyle == .dark {
                return .dark
            }
        }
        #endif

        return .light
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

    class var ohHightlightStrokeColor: UIColor {
        OHInterfaceStyle.current == .light ? .black : .white
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
}

public extension UIColor {
    convenience init(fromString string: String) {
        let namedColors = ["maroon": UIColor.ohMaroon,
                           "red": UIColor.ohRed,
                           "orange": UIColor.ohOrange,
                           "olive": UIColor.ohOlive,
                           "yellow": UIColor.ohYellow,
                           "purple": UIColor.ohPurple,
                           "fuchsia": UIColor.ohFuchsia,
                           "white": UIColor.ohWhite,
                           "lime": UIColor.ohLime,
                           "green": UIColor.ohGreen,
                           "navy": UIColor.ohNavy,
                           "blue": UIColor.ohBlue,
                           "teal": UIColor.ohTeal,
                           "aqua": UIColor.ohAqua,
                           "black": UIColor.ohBlack,
                           "silver": UIColor.ohSilver,
                           "gray": UIColor.ohGray]

        self.init(cgColor: namedColors.first { $0.key == string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }?.value.cgColor ?? UIColor(hex: string).cgColor)
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

        let mask = 0x000000ff
        let aRed = Int(color >> 16) & mask
        let aGreen = Int(color >> 8) & mask
        let aBlue = Int(color) & mask

        let red = CGFloat(aRed) / 255.0
        let green = CGFloat(aGreen) / 255.0
        let blue = CGFloat(aBlue) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
