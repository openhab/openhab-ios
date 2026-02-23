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
struct InputCommandFormatterTests {
    @Test
    func textHintPassesThroughTrimmedInput() {
        let result = InputCommandFormatter.command(from: "  hello world  ", hint: .text)
        #expect(result == "hello world")
    }

    @Test
    func numberHintAcceptsDotDecimal() {
        let result = InputCommandFormatter.command(from: "12.5", hint: .number)
        #expect(result == "12.5")
    }

    @Test
    func numberHintAcceptsCommaDecimalAndNormalizes() {
        let result = InputCommandFormatter.command(from: "12,5", hint: .number)
        #expect(result == "12.5")
    }

    @Test
    func numberHintAcceptsLeadingDecimal() {
        let result = InputCommandFormatter.command(from: ".5", hint: .number)
        #expect(result == "0.5")
    }

    @Test
    func numberHintRejectsInvalidValues() {
        #expect(InputCommandFormatter.command(from: "12..5", hint: .number) == nil)
        #expect(InputCommandFormatter.command(from: "abc", hint: .number) == nil)
        #expect(InputCommandFormatter.command(from: "1,2.3", hint: .number) == nil)
        #expect(InputCommandFormatter.command(from: "1e3", hint: .number) == nil)
        #expect(InputCommandFormatter.command(from: " ", hint: .number) == nil)
    }

    @Test
    func numberHintFiltersInvalidCharactersDuringTyping() {
        let result = InputCommandFormatter.filteredDraftInput(from: "1e2..3,+", hint: .number)
        #expect(result == "12.3")
    }
}
