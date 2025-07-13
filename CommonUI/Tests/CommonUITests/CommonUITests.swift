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

@testable import CommonUI
import Numerics
import Testing

struct ColorTemperatureTests {
    @Test func lowKelvinValue() {
        let color = componentsForColorTemperature(temperature: 1000)
        #expect(color.r.isApproximatelyEqual(to: 1.0, relativeTolerance: 0.01))
        #expect(color.g < 0.5)
        #expect(color.b.isApproximatelyEqual(to: 0.0, relativeTolerance: 0.01))
    }

    @Test func midKelvinValue() {
        let color = componentsForColorTemperature(temperature: 5000)
        #expect(color.r > 0.9)
        #expect(color.g > 0.7)
        #expect(color.b > 0.5)
    }

    @Test func highKelvinValue() {
        let color = componentsForColorTemperature(temperature: 10000)
        #expect(color.r > 0.7)
        #expect(color.g > 0.8)
        #expect(color.b.isApproximatelyEqual(to: 1.0, relativeTolerance: 0.01))
    }

    @Test func edgeKelvinValues() {
        let veryLow = componentsForColorTemperature(temperature: 100)
        #expect(veryLow.r.isApproximatelyEqual(to: 1.0, relativeTolerance: 0.01))
        #expect(veryLow.b.isApproximatelyEqual(to: 0.0, relativeTolerance: 0.01))

        let veryHigh = componentsForColorTemperature(temperature: 40000)
        #expect(veryHigh.r <= 1.0)
        #expect(veryHigh.g <= 1.0)
        #expect(veryHigh.b.isApproximatelyEqual(to: 1.0, relativeTolerance: 0.01))
    }
}
