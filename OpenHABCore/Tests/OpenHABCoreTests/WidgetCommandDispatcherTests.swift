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
import Testing

@Suite
@MainActor
struct WidgetCommandDispatcherTests {
    @Test("Empty string command is dispatched for item name")
    func emptyStringCommandIsDispatchedForItemName() {
        let dispatcher = WidgetCommandDispatcher()
        var received: (itemname: String, command: String)?

        dispatcher.send("", for: "MyItem", policy: .immediate) { itemname, command in
            received = (itemname, command)
        }

        #expect(received?.itemname == "MyItem")
        #expect(received?.command.isEmpty == true)
    }

    @Test("Nil command is still ignored for item name")
    func nilCommandIsIgnoredForItemName() {
        let dispatcher = WidgetCommandDispatcher()
        var callCount = 0

        dispatcher.send(nil, for: "MyItem", policy: .immediate) { _, _ in
            callCount += 1
        }

        #expect(callCount == 0)
    }
}
