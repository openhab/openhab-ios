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

struct CGFloatExtensionTests {
    // MARK: - Basic division

    @Test func integerDividedByDivisor() {
        #expect(CGFloat(state: "360", divisor: 360) == 1.0)
    }

    @Test func halfRange() {
        #expect(CGFloat(state: "180", divisor: 360) == 0.5)
    }

    @Test func percentageValue() {
        #expect(CGFloat(state: "50", divisor: 100) == 0.5)
    }

    @Test func zeroValue() {
        #expect(CGFloat(state: "0", divisor: 360) == 0.0)
    }

    // MARK: - Decimal input

    @Test func decimalWithDot() {
        let result = CGFloat(state: "90.0", divisor: 360)
        #expect(abs(result - 0.25) < 1e-6)
    }

    @Test func decimalWithFractionalPart() {
        let result = CGFloat(state: "33.3", divisor: 100)
        #expect(abs(result - 0.333) < 1e-4)
    }

    // MARK: - Locale robustness

    @Test func stringWithCommaDecimalSeparatorStopsAtComma() {
        // Float(_:format:) with en_US_POSIX parses the numeric prefix and stops at ","
        #expect(CGFloat(state: "90,0", divisor: 360) == 0.25)
    }

    // MARK: - Invalid input

    @Test func emptyStringReturnsZero() {
        #expect(CGFloat(state: "", divisor: 100) == 0.0)
    }

    @Test func nonNumericStringReturnsZero() {
        #expect(CGFloat(state: "abc", divisor: 100) == 0.0)
    }

    @Test func whitespaceStringReturnsZero() {
        #expect(CGFloat(state: "  ", divisor: 100) == 0.0)
    }

    // MARK: - Edge cases

    @Test func largeNumerator() {
        let result = CGFloat(state: "1000", divisor: 100)
        #expect(abs(result - 10.0) < 1e-6)
    }

    @Test func smallFractionalResult() {
        let result = CGFloat(state: "1", divisor: 100)
        #expect(abs(result - 0.01) < 1e-6)
    }
}
