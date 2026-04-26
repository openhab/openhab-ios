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
    @Test func testRemoveTrailingSlashes() async throws {
        #expect("example/".removeTrailingSlashes() == "example")
        #expect("example//".removeTrailingSlashes() == "example")
        #expect("example/path//".removeTrailingSlashes() == "example/path")
        #expect("example/path/".removeTrailingSlashes() == "example/path")
        #expect("example/path".removeTrailingSlashes() == "example/path")
        #expect("/".removeTrailingSlashes() == "")
        #expect("///".removeTrailingSlashes() == "")
        #expect("".removeTrailingSlashes() == "")
    }

    @Test
    func testIsNoneIcon() throws {
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
    func testDataImageBase64Payload() throws {
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
    func testDataImageBase64Data() throws {
        let validPayload = "PHN2Zz48L3N2Zz4="
        #expect("data:image/svg+xml;base64,\(validPayload)".dataImageBase64Data == Data(base64Encoded: validPayload))

        #expect("data:image/png;base64,%%%".dataImageBase64Data == nil)
        #expect("data:image/png;base64,".dataImageBase64Data == Data())
        #expect("data:image/svg+xml,<svg></svg>".dataImageBase64Data == nil)
        #expect("http://example.com/image.png".dataImageBase64Data == nil)
    }

    // MARK: - doubleValue Tests

    @Test func doubleValueWithSimpleInteger() async throws {
        let result = "42".doubleValue
        #expect(result == 42.0)
    }

    @Test func doubleValueWithDecimal() async throws {
        let result = "42.5".doubleValue
        #expect(result == 42.5)
    }

    @Test func doubleValueWithNegative() async throws {
        let result = "-42.5".doubleValue
        #expect(result == -42.5)
    }

    @Test func doubleValueWithZero() async throws {
        let result = "0".doubleValue
        #expect(result == 0.0)
    }

    @Test func doubleValueWithLeadingZeros() async throws {
        let result = "00042.5".doubleValue
        #expect(result == 42.5)
    }

    @Test func doubleValueWithVerySmallNumber() async throws {
        let result = "0.0001".doubleValue
        #expect(result == 0.0001)
    }

    @Test func doubleValueWithVeryLargeNumber() async throws {
        let result = "123456789.123".doubleValue
        #expect(result == 123_456_789.123)
    }

    @Test func doubleValueWithInvalidString() async throws {
        let result = "not a number".doubleValue
        #expect(result.isNaN)
    }

    @Test func doubleValueWithEmptyString() async throws {
        let result = "".doubleValue
        #expect(result.isNaN)
    }

    @Test func doubleValueUsesDecimalPoint() async throws {
        let result = "42.5".doubleValue
        #expect(result == 42.5)
    }

    @Test func doubleValueIgnoresCommaAsDecimalSeparator() async throws {
        // Should parse up to the comma, not treat comma as decimal separator
        let result = "42,5".doubleValue
        // Parser stops at comma and returns 42.0, not 42.5
        #expect(result == 42.0)
    }

    // MARK: - intValue Tests

    @Test func intValueWithSimpleInteger() async throws {
        let result = "42".intValue
        #expect(result == 42)
    }

    @Test func intValueWithNegative() async throws {
        let result = "-42".intValue
        #expect(result == -42)
    }

    @Test func intValueWithZero() async throws {
        let result = "0".intValue
        #expect(result == 0)
    }

    @Test func intValueWithLeadingZeros() async throws {
        let result = "00042".intValue
        #expect(result == 42)
    }

    @Test func intValueWithLargeNumber() async throws {
        let result = "123456789".intValue
        #expect(result == 123_456_789)
    }

    @Test func intValueWithInvalidString() async throws {
        let result = "not a number".intValue
        #expect(result == Int.max)
    }

    @Test func intValueWithEmptyString() async throws {
        let result = "".intValue
        #expect(result == Int.max)
    }

    @Test func intValueWithDecimalString() async throws {
        // Parser stops at decimal point, returns integer part
        let result = "42.5".intValue
        #expect(result == 42)
    }

    // MARK: - numberValue Tests

    @Test func numberValueWithSimpleInteger() async throws {
        let result = "42".numberValue
        #expect(result?.doubleValue == 42.0)
    }

    @Test func numberValueWithDecimal() async throws {
        let result = "42.5".numberValue
        #expect(result?.doubleValue == 42.5)
    }

    @Test func numberValueWithNegative() async throws {
        let result = "-42.5".numberValue
        #expect(result?.doubleValue == -42.5)
    }

    @Test func numberValueWithScientificNotation() async throws {
        let result = "1.23E+2".numberValue
        #expect(result?.doubleValue == 123.0)
    }

    @Test func numberValueWithNegativeExponent() async throws {
        let result = "1.23E-2".numberValue
        #expect(result?.doubleValue == 0.0123)
    }

    @Test func numberValueFiltersInvalidCharacters() async throws {
        let result = "42.5abc".numberValue
        #expect(result?.doubleValue == 42.5)
    }

    @Test func numberValueWithExtraWhitespace() async throws {
        let result = " 42.5 ".numberValue
        #expect(result?.doubleValue == 42.5)
    }

    @Test func numberValueWithInvalidString() async throws {
        let result = "not a number".numberValue
        #expect(result == nil)
    }

    @Test func numberValueWithEmptyString() async throws {
        let result = "".numberValue
        #expect(result == nil)
    }

    @Test func numberValueUsesDecimalPoint() async throws {
        let result = "42.5".numberValue
        #expect(result?.doubleValue == 42.5)
    }

    @Test func numberValueWithZero() async throws {
        let result = "0".numberValue
        #expect(result?.doubleValue == 0.0)
    }

    @Test func numberValueWithPositiveSign() async throws {
        let result = "+42.5".numberValue
        #expect(result?.doubleValue == 42.5)
    }

    @Test func numberValueFiltersLetters() async throws {
        // Should filter out letters but keep valid number characters
        // "1E2abc3" -> filters to "1E23" -> parses as 1 × 10^23
        let result = "1E2abc3".numberValue
        #expect(result?.doubleValue == 1e+23)
    }

    @Test func numberValueFiltersLettersSimple() async throws {
        // Simpler case: "42abc.5def" -> filters to "42.5"
        let result = "42abc.5def".numberValue
        #expect(result?.doubleValue == 42.5)
    }

    @Test func numberValueWithUppercaseScientificNotation() async throws {
        let result = "1.5E+10".numberValue
        #expect(result?.doubleValue == 15_000_000_000.0)
    }

    @Test func numberValueWithScientificNotationNoSign() async throws {
        let result = "1.5E10".numberValue
        #expect(result?.doubleValue == 15_000_000_000.0)
    }

    @Test func numberValueWithVerySmallScientificNumber() async throws {
        let result = "1.0E-10".numberValue
        #expect(result?.doubleValue == 0.0000000001)
    }

    @Test func numberValueWithZeroExponent() async throws {
        let result = "1.5E0".numberValue
        #expect(result?.doubleValue == 1.5)
    }

    // MARK: - asDouble Tests

    @Test func asDoubleWithValidNumber() async throws {
        let result = "42.5".asDouble
        #expect(result == 42.5)
    }

    @Test func asDoubleWithInvalidString() async throws {
        let result = "not a number".asDouble
        #expect(result == 0.0)
    }

    @Test func asDoubleWithEmptyString() async throws {
        let result = "".asDouble
        #expect(result == 0.0)
    }

    @Test func asDoubleWithScientificNotation() async throws {
        let result = "1.23E+2".asDouble
        #expect(result == 123.0)
    }
}
