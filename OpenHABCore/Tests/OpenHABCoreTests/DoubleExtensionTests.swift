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

struct DoubleExtensionTests {
    @Test
    func valueTextWithNoDecimalPlaces() throws {
        let value = 42.0
        let step = 1.0
        let result = value.valueText(step: step)
        #expect(result == "42")
    }

    @Test
    func valueTextWithOneDecimalPlace() throws {
        let value = 42.5
        let step = 0.1
        let result = value.valueText(step: step)
        #expect(result == "42.5")
    }

    @Test
    func valueTextWithTwoDecimalPlaces() throws {
        let value = 42.75
        let step = 0.01
        let result = value.valueText(step: step)
        #expect(result == "42.75")
    }

    @Test
    func valueTextWithThreeDecimalPlaces() throws {
        let value = 3.142
        let step = 0.001
        let result = value.valueText(step: step)
        #expect(result == "3.142")
    }

    @Test
    func valueTextRoundsToStepPrecision() throws {
        let value = 3.14159
        let step = 0.01
        let result = value.valueText(step: step)
        #expect(result == "3.14")
    }

    @Test
    func valueTextWithZeroValue() throws {
        let value = 0.0
        let step = 0.1
        let result = value.valueText(step: step)
        #expect(result == "0.0")
    }

    @Test
    func valueTextWithNegativeValue() throws {
        let value = -42.5
        let step = 0.1
        let result = value.valueText(step: step)
        #expect(result == "-42.5")
    }

    @Test
    func valueTextWithVerySmallStep() throws {
        let value = 1.23456789
        let step = 0.00001
        let result = value.valueText(step: step)
        #expect(result == "1.23457")
    }

    @Test
    func valueTextPadsTrailingZeros() throws {
        let value = 42.0
        let step = 0.01
        let result = value.valueText(step: step)
        #expect(result == "42.00")
    }

    @Test
    func valueTextWithLargeValue() throws {
        let value = 12345.67
        let step = 0.1
        let result = value.valueText(step: step)
        #expect(result == "12345.7")
    }

    @Test
    func valueTextUsesDecimalPoint() throws {
        let value = 1234.5
        let step = 0.1
        let result = value.valueText(step: step)
        #expect(result.contains("."))
        #expect(!result.contains(","))
    }

    @Test
    func valueTextNoThousandsSeparator() throws {
        let value = 1_000_000.0
        let step = 1.0
        let result = value.valueText(step: step)
        #expect(result == "1000000")
    }
}
