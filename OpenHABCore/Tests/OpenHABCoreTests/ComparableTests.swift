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

struct ComparableTests {
    @Test
    func clampedWithValueBelowRange() {
        // Int
        #expect((5.clamped(to: 10 ... 20) == 10))

        // Double
        let a = 5.5
        #expect(a.clamped(to: 10.5 ... 20.5) == 10.5)

        // String
        #expect("a".clamped(to: "b" ... "z") == "b")
    }

    @Test
    func clampedWithValueAboveRange() {
        // Int
        #expect(25.clamped(to: 10 ... 20) == 20)

        // Double
        let a = 25.5
        #expect(a.clamped(to: 10.5 ... 20.5) == 20.5)

        // String
        #expect("zz".clamped(to: "b" ... "z") == "z")
    }

    @Test
    func clampedWithValueAtLowerBound() {
        #expect(10.clamped(to: 10 ... 20) == 10)
    }

    @Test
    func clampedWithValueAtUpperBound() {
        #expect(20.clamped(to: 10 ... 20) == 20)
    }

    @Test
    func clampedWithValueWithinRange() {
        #expect(15.clamped(to: 10 ... 20) == 15)
    }

    @Test
    func clampedWithCustomType() {
        struct TestComparable: Comparable {
            let value: Int

            static func < (lhs: TestComparable, rhs: TestComparable) -> Bool {
                lhs.value < rhs.value
            }

            static func == (lhs: TestComparable, rhs: TestComparable) -> Bool {
                lhs.value == rhs.value
            }
        }

        let below = TestComparable(value: 5)
        let min = TestComparable(value: 10)
        let middle = TestComparable(value: 15)
        let max = TestComparable(value: 20)
        let above = TestComparable(value: 25)

        #expect(below.clamped(to: min ... max) == min)
        #expect(middle.clamped(to: min ... max) == middle)
        #expect(above.clamped(to: min ... max) == max)
    }
}
