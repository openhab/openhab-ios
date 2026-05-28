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

import OpenHABCore
import Testing
import UIKit

struct UIColorTests {
    @Test
    func resolvesNamedColor_exactMatch() {
        #expect(UIColor(fromString: "red") == .ohRed)
    }

    @Test
    func resolvesNamedColor_caseInsensitive() {
        #expect(UIColor(fromString: "NAvY") == .ohNavy)
    }

    @Test
    func resolvesNamedColor_withWhitespace() {
        #expect(UIColor(fromString: "  green  ") == .ohGreen)
    }

    @Test
    func fallsBackToHexParsing() {
        #expect(UIColor(fromString: "#FF0000") == UIColor(hex: "#FF0000"))
    }

    @Test
    func returnsFallbackForInvalidColor() {
        let color = UIColor(fromString: "notAColor")
        let fallback = UIColor(hex: "notAColor")
        #expect(color == fallback)
    }

    @Test
    func hexStringForMultipleColors() {
        // Array of (UIColor, expectedHexString)
        let testCases: [(UIColor, String?)] = [
            (UIColor.red, "FF0000"),
            (UIColor.green, "00FF00"),
            (UIColor.blue, "0000FF"),
            (UIColor.white, "FFFFFF"),
            (UIColor.black, "000000"),
            (UIColor(red: 1, green: 0, blue: 0, alpha: 0.5), "FF000080"), // 50% alpha
            (UIColor(patternImage: UIImage()), nil) // Non-RGB color should return nil
        ]

        for (index, testCase) in testCases.enumerated() {
            let (color, expectedHex) = testCase
            #expect(
                color.hexString == expectedHex,
                "Case \(index): Expected \(expectedHex ?? "nil"), got \(color.hexString ?? "nil")"
            )
        }
    }
}
