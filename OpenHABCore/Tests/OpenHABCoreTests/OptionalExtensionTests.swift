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

struct OptionalExtensionTests {
    @Test("nil, or a value that matches, is true; a value that doesn't match is false")
    func isNilOrMatches() {
        let none: Int? = nil
        #expect(none.isNil { $0 > 3 })
        #expect(Optional(5).isNil { $0 > 3 })
        #expect(!Optional(2).isNil { $0 > 3 })
    }

    @Test("A key path works as the expression")
    func isNilOrKeyPath() {
        #expect(Optional([Int]()).isNil(or: \.isEmpty))
        #expect(!Optional([1]).isNil(or: \.isEmpty))
    }

    @Test("nil and empty strings are nil or empty, text is not")
    func stringIsNilOrEmpty() {
        let none: String? = nil
        #expect(none.isNilOrEmpty)
        #expect(Optional("").isNilOrEmpty)
        #expect(!Optional("ON").isNilOrEmpty)
        #expect(!Optional(" ").isNilOrEmpty, "Whitespace is not empty")
    }

    @Test("Works for any collection, not only strings")
    func collectionIsNilOrEmpty() {
        let noArray: [Int]? = nil
        #expect(noArray.isNilOrEmpty)
        #expect(Optional([Int]()).isNilOrEmpty)
        #expect(!Optional([1, 2]).isNilOrEmpty)
        #expect(Optional([String: Int]()).isNilOrEmpty)
        #expect(!Optional(["a": 1]).isNilOrEmpty)
    }
}
