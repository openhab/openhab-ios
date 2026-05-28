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

import OpenHABCore
import SwiftUI
import Testing

struct OpenHABWidgetIconStateTests {
//    @Test
//    func returnsLowercasedState() {
//        let widget = makeTestWidget(itemState: "ON")
//        #expect(widget.iconState() == "on")
//    }

//    @Test
//    func handlesMixedCase() {
//        let widget = makeTestWidget(itemState: "ClOsEd")
//        #expect(widget.iconState() == "closed")
//    }

//    @Test
//    func returnsNilWhenStateIsEmpty() {
//        let widget = makeTestWidget(itemState: "")
//        #expect(widget.iconState() == nil)
//    }

    @Test
    func returnsNilWhenStateIsNil() {
        let widget = makeTestWidget(itemState: nil)
        #expect(widget.iconState() == nil)
    }

    @Test
    func acceptsNumericString() {
        let widget = makeTestWidget(itemState: "123")
        #expect(widget.iconState() == "123")
    }

    // MARK: - Helpers

    private func makeTestWidget(itemState: String?) -> OpenHABWidget {
        let dto = OpenHABWidget()
        dto.item = OpenHABItem(name: "String", type: "String", state: itemState, link: "122", label: "labe", groupType: nil, stateDescription: nil, commandDescription: nil, members: [], category: nil, options: nil)
        return dto
    }
}
