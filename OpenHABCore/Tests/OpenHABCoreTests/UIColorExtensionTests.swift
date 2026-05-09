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

@testable import OpenHABCore
import Testing
import UIKit

struct UIColorExtensionTests {
    // MARK: - semanticColorToHex() Tests

    @Test func semanticColorToHex_RegularRGBColors() throws {
        // Test regular RGB colors created from hex values
        let redColor = UIColor(hex: "#FF0000")
        #expect(redColor.semanticColorToHex() == "#FF0000")

        let greenColor = UIColor(hex: "#00FF00")
        #expect(greenColor.semanticColorToHex() == "#00FF00")

        let blueColor = UIColor(hex: "#0000FF")
        #expect(blueColor.semanticColorToHex() == "#0000FF")

        let customColor = UIColor(hex: "#A1B2C3")
        #expect(customColor.semanticColorToHex() == "#A1B2C3")
    }

    @Test func semanticColorToHex_GrayscaleColors() throws {
        // Test grayscale colors (black, white, gray)
        let blackColor = UIColor.black
        #expect(blackColor.semanticColorToHex() == "#000000")

        let whiteColor = UIColor.white
        #expect(whiteColor.semanticColorToHex() == "#FFFFFF")

        let grayColor = UIColor.gray
        let grayHex = grayColor.semanticColorToHex()
        #expect(grayHex != nil)
        #expect(grayHex?.hasPrefix("#") == true)
    }

    @Test func semanticColorToHex_SemanticOHColors() throws {
        // Test openHAB semantic colors
        let ohBlackColor = UIColor.ohBlack
        let ohBlackHex = ohBlackColor.semanticColorToHex()
        #expect(ohBlackHex != nil)
        #expect(ohBlackHex?.hasPrefix("#") == true)

        let ohWhiteColor = UIColor.ohWhite
        let ohWhiteHex = ohWhiteColor.semanticColorToHex()
        #expect(ohWhiteHex != nil)
        #expect(ohWhiteHex?.hasPrefix("#") == true)

        let ohRedColor = UIColor.ohRed
        #expect(ohRedColor.semanticColorToHex() == "#FF0000")

        let ohGreenColor = UIColor.ohGreen
        #expect(ohGreenColor.semanticColorToHex() == "#008000")

        let ohBlueColor = UIColor.ohBlue
        #expect(ohBlueColor.semanticColorToHex() == "#0000FF")
    }

    @Test func semanticColorToHex_StandardColors() throws {
        // Test standard UIColor colors
        let redColor = UIColor.red
        let redHex = redColor.semanticColorToHex()
        #expect(redHex != nil)
        #expect(redHex?.hasPrefix("#") == true)

        let greenColor = UIColor.green
        let greenHex = greenColor.semanticColorToHex()
        #expect(greenHex != nil)
        #expect(greenHex?.hasPrefix("#") == true)

        let blueColor = UIColor.blue
        let blueHex = blueColor.semanticColorToHex()
        #expect(blueHex != nil)
        #expect(blueHex?.hasPrefix("#") == true)

        let yellowColor = UIColor.yellow
        let yellowHex = yellowColor.semanticColorToHex()
        #expect(yellowHex != nil)
        #expect(yellowHex?.hasPrefix("#") == true)
    }

    @Test func semanticColorToHex_CustomRGBColors() throws {
        // Test colors created with custom RGB values
        let customColor1 = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        let hex1 = customColor1.semanticColorToHex()
        #expect(hex1 != nil)
        #expect(hex1?.hasPrefix("#") == true)
        #expect(hex1 == "#808080")

        let customColor2 = UIColor(red: 1.0, green: 0.0, blue: 0.5, alpha: 1.0)
        let hex2 = customColor2.semanticColorToHex()
        #expect(hex2 != nil)
        #expect(hex2?.hasPrefix("#") == true)
        #expect(hex2 == "#FF0080")

        let customColor3 = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        #expect(customColor3.semanticColorToHex() == "#000000")

        let customColor4 = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        #expect(customColor4.semanticColorToHex() == "#FFFFFF")
    }

    @Test func semanticColorToHex_AllOHNamedColors() throws {
        // Test all openHAB named colors to ensure they convert successfully
        let colors: [(UIColor, String)] = [
            (.ohMaroon, "#800000"),
            (.ohRed, "#FF0000"),
            (.ohOrange, "#FFA500"),
            (.ohOlive, "#808000"),
            (.ohYellow, "#FFFF00"),
            (.ohPurple, "#800080"),
            (.ohFuchsia, "#FF00FF"),
            (.ohLime, "#00FF00"),
            (.ohGreen, "#008000"),
            (.ohNavy, "#000080"),
            (.ohBlue, "#0000FF"),
            (.ohTeal, "#008080"),
            (.ohAqua, "#00FFFF"),
            (.ohSilver, "#C0C0C0"),
            (.ohGray, "#808080")
        ]

        for (color, expectedHex) in colors {
            let hex = color.semanticColorToHex()
            #expect(hex == expectedHex)
        }
    }

    @Test func semanticColorToHex_EdgeCases() throws {
        // Test edge case colors with transparency
        let transparentColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.5)
        let transparentHex = transparentColor.semanticColorToHex()
        // Should still return hex (alpha is not included in the hex string)
        #expect(transparentHex != nil)
        #expect(transparentHex?.hasPrefix("#") == true)

        // Test fully transparent color
        let fullyTransparent = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        let fullyTransparentHex = fullyTransparent.semanticColorToHex()
        #expect(fullyTransparentHex != nil)

        // Test clear color
        let clearColor = UIColor.clear
        let clearHex = clearColor.semanticColorToHex()
        #expect(clearHex != nil)
    }

    @Test func semanticColorToHex_HexFormat() throws {
        // Verify that all returned hex strings start with '#'
        let testColors = [
            UIColor.black,
            UIColor.white,
            UIColor.red,
            UIColor.ohBlack,
            UIColor.ohBlue,
            UIColor(hex: "#123456")
        ]

        for color in testColors {
            if let hex = color.semanticColorToHex() {
                #expect(hex.hasPrefix("#"))
                #expect(hex.count == 7) // # + 6 hex digits
            }
        }
    }

    // MARK: - toHex() Tests

    @Test func toHex_BasicColors() throws {
        let redColor = UIColor(hex: "#FF0000")
        #expect(redColor.toHex() == "FF0000")

        let greenColor = UIColor(hex: "#00FF00")
        #expect(greenColor.toHex() == "00FF00")

        let blueColor = UIColor(hex: "#0000FF")
        #expect(blueColor.toHex() == "0000FF")
    }

    @Test func toHex_WithAlpha() throws {
        let color = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.5)
        let hexWithAlpha = color.toHex(alpha: true)
        #expect(hexWithAlpha != nil)
        #expect(hexWithAlpha?.count == 8) // 8 hex digits with alpha
    }

    // MARK: - init(hex:) Tests

    @Test func initFromHex_ValidHexStrings() throws {
        let color1 = UIColor(hex: "#FF0000")
        #expect(color1.toHex() == "FF0000")

        let color2 = UIColor(hex: "00FF00")
        #expect(color2.toHex() == "00FF00")

        let color3 = UIColor(hex: "#0000ff")
        #expect(color3.toHex() == "0000FF")
    }

    @Test func initFromHex_InvalidHexStrings() throws {
        // Test that invalid hex strings fall back to gray
        let invalidColor1 = UIColor(hex: "ABC")
        #expect(invalidColor1.toHex() == UIColor.gray.toHex())

        let invalidColor2 = UIColor(hex: "")
        #expect(invalidColor2.toHex() == UIColor.gray.toHex())
    }

    // MARK: - init(fromString:) Tests

    @Test func initFromString_NamedColors() throws {
        let redColor = UIColor(fromString: "red")
        #expect(redColor.semanticColorToHex() == "#FF0000")

        let blueColor = UIColor(fromString: "blue")
        #expect(blueColor.semanticColorToHex() == "#0000FF")

        let maroonColor = UIColor(fromString: "maroon")
        #expect(maroonColor.semanticColorToHex() == "#800000")
    }

    @Test func initFromString_HexStrings() throws {
        let color1 = UIColor(fromString: "#FF0000")
        #expect(color1.semanticColorToHex() == "#FF0000")

        let color2 = UIColor(fromString: "00FF00")
        #expect(color2.semanticColorToHex() == "#00FF00")
    }

    @Test func initFromString_CaseInsensitive() throws {
        let color1 = UIColor(fromString: "RED")
        let color2 = UIColor(fromString: "red")
        let color3 = UIColor(fromString: "Red")

        #expect(color1.semanticColorToHex() == color2.semanticColorToHex())
        #expect(color2.semanticColorToHex() == color3.semanticColorToHex())
    }

    @Test func initFromString_WhitespaceHandling() throws {
        let color1 = UIColor(fromString: "  red  ")
        #expect(color1.semanticColorToHex() == "#FF0000")

        let color2 = UIColor(fromString: "  #FF0000  ")
        #expect(color2.semanticColorToHex() == "#FF0000")
    }

    @Test func initFromString_InvalidString() throws {
        // Test that short invalid strings fall back to gray
        let shortInvalidColor = UIColor(fromString: "xyz")
        #expect(shortInvalidColor.toHex() == UIColor.gray.toHex())

        // Test that unrecognized color names that contain hex chars still produce a color
        let invalidColor = UIColor(fromString: "notacolor")
        let hex = invalidColor.semanticColorToHex()
        #expect(hex != nil)
        #expect(hex?.hasPrefix("#") == true)
    }
}
