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

private enum TestValues {
    static let oversizedKelvin = 15000.0
    static let miredWarmest = 370.0
    static let miredCoolest = 153.0
    static let convertedWarmestKelvin = 2702.7027027027025
    static let convertedCoolestKelvin = 6535.947712418301
    static let miredState = "250"
    static let convertedStateKelvin = 4000.0
    static let invalidState = "not-a-number"
    static let clampedServerValue = 6500.0
    static let oversizedServerValue = 9000.0
    static let minimumRangeKelvin = 1000.0
    static let narrowMaximumKelvin = 6500.0
    static let degenerateRangeKelvin = 4000.0
    static let gradientStartKelvin = 2000.0
    static let gradientEndKelvin = 3000.0
    static let gradientSteps = 4
    static let gradientCount = 5
    static let tolerance = 0.0001
    static let zero = 0.0
}

struct ColorTemperatureRowMathTests {
    @Test
    func normalizedRangeUsesFallbackForZeroSpan() {
        let range = ColorTemperatureRowMath.normalizedRange(
            minValue: TestValues.oversizedKelvin,
            maxValue: TestValues.oversizedKelvin
        )

        #expect(range.lowerBound == ColorTemperatureRowMath.minimumKelvin)
        #expect(range.upperBound == ColorTemperatureRowMath.maximumKelvin)
    }

    @Test
    func normalizedRangeConvertsMiredBoundsToKelvin() {
        let range = ColorTemperatureRowMath.normalizedRange(
            minValue: TestValues.miredWarmest,
            maxValue: TestValues.miredCoolest
        )

        #expect(abs(range.lowerBound - TestValues.convertedWarmestKelvin) < TestValues.tolerance)
        #expect(abs(range.upperBound - TestValues.convertedCoolestKelvin) < TestValues.tolerance)
    }

    @Test
    func normalizedTemperatureConvertsMiredStateAndClampsIntoRange() {
        let range = ColorTemperatureRowMath.normalizedRange(
            minValue: TestValues.miredWarmest,
            maxValue: TestValues.miredCoolest
        )

        let temperature = ColorTemperatureRowMath.normalizedTemperature(
            state: TestValues.miredState,
            serverValue: nil,
            range: range
        )

        #expect(temperature == TestValues.convertedStateKelvin)
    }

    @Test
    func normalizedTemperatureFallsBackToClampedServerValue() {
        let range = ColorTemperatureRowMath.normalizedRange(
            minValue: TestValues.minimumRangeKelvin,
            maxValue: TestValues.narrowMaximumKelvin
        )

        let temperature = ColorTemperatureRowMath.normalizedTemperature(
            state: TestValues.invalidState,
            serverValue: TestValues.oversizedServerValue,
            range: range
        )

        #expect(temperature == TestValues.clampedServerValue)
    }

    @Test
    func sliderFractionReturnsZeroForDegenerateRange() {
        let fraction = ColorTemperatureRowMath.sliderFraction(
            value: TestValues.gradientEndKelvin,
            range: TestValues.degenerateRangeKelvin ... TestValues.degenerateRangeKelvin
        )

        #expect(fraction == TestValues.zero)
    }

    @Test
    func gradientTemperaturesAlwaysIncludeBothBounds() {
        let temperatures = ColorTemperatureRowMath.gradientTemperatures(
            for: TestValues.gradientStartKelvin ... TestValues.gradientEndKelvin,
            steps: TestValues.gradientSteps
        )

        #expect(temperatures.count == TestValues.gradientCount)
        #expect(temperatures.first == TestValues.gradientStartKelvin)
        #expect(temperatures.last == TestValues.gradientEndKelvin)
    }
}
