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

struct SetpointServiceTests {
    var setpointService = SetPointService()

    @Test
    func increaseValue() {
        let result = setpointService.calculateNewValue(
            currentValue: 20.0,
            step: 0.5,
            minValue: 10.0,
            maxValue: 30.0,
            isDecreasing: false
        )
        #expect(result == 20.5)
    }

    @Test
    func decreaseValue() {
        let result = setpointService.calculateNewValue(
            currentValue: 20.0,
            step: 0.5,
            minValue: 10.0,
            maxValue: 30.0,
            isDecreasing: true
        )
        #expect(result == 19.5)
    }

    @Test
    func upperBoundary() {
        let result = setpointService.calculateNewValue(
            currentValue: 29.8,
            step: 0.5,
            minValue: 10.0,
            maxValue: 30.0,
            isDecreasing: false
        )
        #expect(result == 30.0)
    }

    @Test
    func lowerBoundary() {
        let result = setpointService.calculateNewValue(
            currentValue: 10.2,
            step: 0.5,
            minValue: 10.0,
            maxValue: 30.0,
            isDecreasing: true
        )
        #expect(result == 10.0)
    }
}
