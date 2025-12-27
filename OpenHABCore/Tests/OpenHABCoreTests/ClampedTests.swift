// Copyright (c) 2010-2025 Contributors to the openHAB project
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

@Suite("SetPointService.calculateNewValue")
struct SetPointServiceTests {
    let service = SetPointService()

    @Test
    func increasesWithinBounds() {
        let newValue = service.calculateNewValue(currentValue: 2.0, step: 0.5, minValue: 0.0, maxValue: 5.0, isDecreasing: false)
        #expect(newValue == 2.5)
    }

    @Test
    func decreasesWithinBounds() {
        let newValue = service.calculateNewValue(currentValue: 2.0, step: 0.5, minValue: 0.0, maxValue: 5.0, isDecreasing: true)
        #expect(newValue == 1.5)
    }

    @Test
    func clampsOnDecreaseBelowMin() {
        let newValue = service.calculateNewValue(currentValue: 0.3, step: 1.0, minValue: 0.0, maxValue: 5.0, isDecreasing: true)
        #expect(newValue == 0.0)
    }

    @Test
    func clampsOnIncreaseAboveMax() {
        let newValue = service.calculateNewValue(currentValue: 4.8, step: 1.0, minValue: 0.0, maxValue: 5.0, isDecreasing: false)
        #expect(newValue == 5.0)
    }
}

@Suite("Comparable.clamped")
struct ClampedTests {
    @Test
    func clampsDouble_belowLowerBound() {
        let result = (-10.0).clamped(to: 0.0 ... 5.0)
        #expect(result == 0.0)
    }

    @Test
    func clampsDouble_aboveUpperBound() {
        let result = 10.0.clamped(to: 0.0 ... 5.0)
        #expect(result == 5.0)
    }

    @Test
    func returnsDouble_whenInsideRange() {
        let result = 3.0.clamped(to: 0.0 ... 5.0)
        #expect(result == 3.0)
    }

    @Test
    func clampsInt_values() {
        #expect((-5).clamped(to: 0 ... 10) == 0)
        #expect(5.clamped(to: 0 ... 10) == 5)
        #expect(15.clamped(to: 0 ... 10) == 10)
    }

    @Test
    func clampsAtExactBounds() {
        #expect(0.0.clamped(to: 0.0 ... 5.0) == 0.0)
        #expect(5.0.clamped(to: 0.0 ... 5.0) == 5.0)
    }
}
