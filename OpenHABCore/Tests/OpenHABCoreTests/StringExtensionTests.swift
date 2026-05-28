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

struct StringExtensionTests {
    @Test func testRemoveTrailingSlashes() {
        #expect("example/".removeTrailingSlashes() == "example")
        #expect("example//".removeTrailingSlashes() == "example")
        #expect("example/path//".removeTrailingSlashes() == "example/path")
        #expect("example/path/".removeTrailingSlashes() == "example/path")
        #expect("example/path".removeTrailingSlashes() == "example/path")
        #expect("/".removeTrailingSlashes().isEmpty)
        #expect("///".removeTrailingSlashes().isEmpty)
        #expect("".removeTrailingSlashes().isEmpty)
    }

    @Test
    func testIsNoneIcon() {
        let testCases: [String: Bool] = [
            "none": true,
            "oh:none": true,
            "oh:classic:none": true,
            "oh:foo:none": true,
            "f7:none": false,
            "lights": false
        ]

        for (input, expected) in testCases {
            #expect(input.isNoneIcon == expected, "\(input) failed")
        }
    }

    @Test
    func testDataImageBase64Payload() {
        let svgPayload = "PHN2Zz48L3N2Zz4="
        #expect("data:image/svg+xml;base64,\(svgPayload)".dataImageBase64Payload == svgPayload)

        let pngPayload = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB"
        #expect("data:image/png;base64,\(pngPayload)".dataImageBase64Payload == pngPayload)

        #expect("data:image/svg+xml;base64".dataImageBase64Payload == nil)
        #expect("data:image/svg+xml,<svg></svg>".dataImageBase64Payload == nil) // plain data URI must not be treated as base64
        #expect("http://example.com/image.png".dataImageBase64Payload == nil)
        #expect("".dataImageBase64Payload == nil)
    }

    @Test
    func testDataImageBase64Data() {
        let validPayload = "PHN2Zz48L3N2Zz4="
        #expect("data:image/svg+xml;base64,\(validPayload)".dataImageBase64Data == Data(base64Encoded: validPayload))

        #expect("data:image/png;base64,%%%".dataImageBase64Data == nil)
        #expect("data:image/png;base64,".dataImageBase64Data == Data())
        #expect("data:image/svg+xml,<svg></svg>".dataImageBase64Data == nil)
        #expect("http://example.com/image.png".dataImageBase64Data == nil)
    }

    // MARK: - doubleValue Tests

    @Test func doubleValueWithSimpleInteger() {
        let result = "42".doubleValue
        #expect(result == 42.0)
    }

    @Test func doubleValueWithDecimal() {
        let result = "42.5".doubleValue
        #expect(result == 42.5)
    }

    @Test func doubleValueWithNegative() {
        let result = "-42.5".doubleValue
        #expect(result == -42.5)
    }

    @Test func doubleValueWithZero() {
        let result = "0".doubleValue
        #expect(result == 0.0)
    }

    @Test func doubleValueWithLeadingZeros() {
        let result = "00042.5".doubleValue
        #expect(result == 42.5)
    }

    @Test func doubleValueWithVerySmallNumber() {
        let result = "0.0001".doubleValue
        #expect(result == 0.0001)
    }

    @Test func doubleValueWithVeryLargeNumber() {
        let result = "123456789.123".doubleValue
        #expect(result == 123_456_789.123)
    }

    @Test func doubleValueWithInvalidString() {
        let result = "not a number".doubleValue
        #expect(result.isNaN)
    }

    @Test func doubleValueWithEmptyString() {
        let result = "".doubleValue
        #expect(result.isNaN)
    }

    @Test func doubleValueUsesDecimalPoint() {
        let result = "42.5".doubleValue
        #expect(result == 42.5)
    }

    @Test func doubleValueIgnoresCommaAsDecimalSeparator() {
        // Should parse up to the comma, not treat comma as decimal separator
        let result = "42,5".doubleValue
        // Parser stops at comma and returns 42.0, not 42.5
        #expect(result == 42.0)
    }

    // MARK: - intValue Tests

    @Test func intValueWithSimpleInteger() {
        let result = "42".intValue
        #expect(result == 42)
    }

    @Test func intValueWithNegative() {
        let result = "-42".intValue
        #expect(result == -42)
    }

    @Test func intValueWithZero() {
        let result = "0".intValue
        #expect(result == 0)
    }

    @Test func intValueWithLeadingZeros() {
        let result = "00042".intValue
        #expect(result == 42)
    }

    @Test func intValueWithLargeNumber() {
        let result = "123456789".intValue
        #expect(result == 123_456_789)
    }

    @Test func intValueWithInvalidString() {
        let result = "not a number".intValue
        #expect(result == Int.max)
    }

    @Test func intValueWithEmptyString() {
        let result = "".intValue
        #expect(result == Int.max)
    }

    @Test func intValueWithDecimalString() {
        // Parser stops at decimal point, returns integer part
        let result = "42.5".intValue
        #expect(result == 42)
    }

    // MARK: - numberValue Tests

    @Test func numberValueWithSimpleInteger() {
        let result = "42".numberValue
        #expect(result?.doubleValue == 42.0)
    }

    @Test func numberValueWithDecimal() {
        let result = "42.5".numberValue
        #expect(result?.doubleValue == 42.5)
    }

    @Test func numberValueWithNegative() {
        let result = "-42.5".numberValue
        #expect(result?.doubleValue == -42.5)
    }

    @Test func numberValueWithScientificNotation() {
        let result = "1.23E+2".numberValue
        #expect(result?.doubleValue == 123.0)
    }

    @Test func numberValueWithNegativeExponent() {
        let result = "1.23E-2".numberValue
        #expect(result?.doubleValue == 0.0123)
    }

    @Test func numberValueFiltersInvalidCharacters() {
        let result = "42.5abc".numberValue
        #expect(result?.doubleValue == 42.5)
    }

    @Test func numberValueWithExtraWhitespace() {
        let result = " 42.5 ".numberValue
        #expect(result?.doubleValue == 42.5)
    }

    @Test func numberValueWithInvalidString() {
        let result = "not a number".numberValue
        #expect(result == nil)
    }

    @Test func numberValueWithEmptyString() {
        let result = "".numberValue
        #expect(result == nil)
    }

    @Test func numberValueUsesDecimalPoint() {
        let result = "42.5".numberValue
        #expect(result?.doubleValue == 42.5)
    }

    @Test func numberValueWithZero() {
        let result = "0".numberValue
        #expect(result?.doubleValue == 0.0)
    }

    @Test func numberValueWithPositiveSign() {
        let result = "+42.5".numberValue
        #expect(result?.doubleValue == 42.5)
    }

    @Test func numberValueFiltersLetters() {
        // Should filter out letters but keep valid number characters
        // "1E2abc3" -> filters to "1E23" -> parses as 1 × 10^23
        let result = "1E2abc3".numberValue
        #expect(result?.doubleValue == 1e+23)
    }

    @Test func numberValueFiltersLettersSimple() {
        // Simpler case: "42abc.5def" -> filters to "42.5"
        let result = "42abc.5def".numberValue
        #expect(result?.doubleValue == 42.5)
    }

    @Test func numberValueWithUppercaseScientificNotation() {
        let result = "1.5E+10".numberValue
        #expect(result?.doubleValue == 15_000_000_000.0)
    }

    @Test func numberValueWithScientificNotationNoSign() {
        let result = "1.5E10".numberValue
        #expect(result?.doubleValue == 15_000_000_000.0)
    }

    @Test func numberValueWithVerySmallScientificNumber() {
        let result = "1.0E-10".numberValue
        #expect(result?.doubleValue == 0.0000000001)
    }

    @Test func numberValueWithZeroExponent() {
        let result = "1.5E0".numberValue
        #expect(result?.doubleValue == 1.5)
    }

    // MARK: - asDouble Tests

    @Test func asDoubleWithValidNumber() {
        let result = "42.5".asDouble
        #expect(result == 42.5)
    }

    @Test func asDoubleWithInvalidString() {
        let result = "not a number".asDouble
        #expect(result == 0.0)
    }

    @Test func asDoubleWithEmptyString() {
        let result = "".asDouble
        #expect(result == 0.0)
    }

    @Test func asDoubleWithScientificNotation() {
        let result = "1.23E+2".asDouble
        #expect(result == 123.0)
    }
}
