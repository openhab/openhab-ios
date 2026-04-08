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

@testable import openHAB

import Testing

@Suite
struct ColorTemperatureRowMathTests {
    @Test
    func normalizedRangeUsesFallbackForZeroSpan() {
        let range = ColorTemperatureRowMath.normalizedRange(minValue: 15000, maxValue: 15000)

        #expect(range.lowerBound == 1000)
        #expect(range.upperBound == 10000)
    }

    @Test
    func normalizedRangeConvertsMiredBoundsToKelvin() {
        let range = ColorTemperatureRowMath.normalizedRange(minValue: 370, maxValue: 153)

        #expect(abs(range.lowerBound - 2702.7027027027025) < 0.0001)
        #expect(abs(range.upperBound - 6535.947712418301) < 0.0001)
    }

    @Test
    func normalizedTemperatureConvertsMiredStateAndClampsIntoRange() {
        let range = ColorTemperatureRowMath.normalizedRange(minValue: 370, maxValue: 153)

        let temperature = ColorTemperatureRowMath.normalizedTemperature(
            state: "250",
            serverValue: nil,
            range: range
        )

        #expect(temperature == 4000)
    }

    @Test
    func normalizedTemperatureFallsBackToClampedServerValue() {
        let range = ColorTemperatureRowMath.normalizedRange(minValue: 1000, maxValue: 6500)

        let temperature = ColorTemperatureRowMath.normalizedTemperature(
            state: "not-a-number",
            serverValue: 9000,
            range: range
        )

        #expect(temperature == 6500)
    }

    @Test
    func sliderFractionReturnsZeroForDegenerateRange() {
        let fraction = ColorTemperatureRowMath.sliderFraction(value: 3000, range: 4000 ... 4000)

        #expect(fraction == 0)
    }

    @Test
    func gradientTemperaturesAlwaysIncludeBothBounds() {
        let temperatures = ColorTemperatureRowMath.gradientTemperatures(for: 2000 ... 3000, steps: 4)

        #expect(temperatures.count == 5)
        #expect(temperatures.first == 2000)
        #expect(temperatures.last == 3000)
    }
}
