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

    @Test("Throttle sends the first value immediately and the latest value on the interval")
    func throttleSendsWhileValuesKeepArriving() async {
        let dispatcher = WidgetCommandDispatcher()
        var commands: [String] = []
        let policy = WidgetCommandPolicy.throttle(.milliseconds(60))

        func send(_ command: String) {
            dispatcher.send(command, for: "Dimmer", policy: policy, key: "slider") { _, sent in
                commands.append(sent)
            }
        }

        send("10")
        send("20")
        send("30")
        #expect(commands == ["10"])

        try? await Task.sleep(for: .milliseconds(400))
        #expect(commands == ["10", "30"])

        send("55")
        #expect(commands == ["10", "30", "55"])
    }

    @Test("Cancelling a throttle drops the value that has not been sent yet")
    func throttleCancelDropsTheUnsentValue() async {
        let dispatcher = WidgetCommandDispatcher()
        var commands: [String] = []
        let policy = WidgetCommandPolicy.throttle(.milliseconds(60))

        dispatcher.send("10", for: "Dimmer", policy: policy, key: "slider") { _, sent in
            commands.append(sent)
        }
        dispatcher.send("40", for: "Dimmer", policy: policy, key: "slider") { _, sent in
            commands.append(sent)
        }
        dispatcher.cancelPending(for: "Dimmer", key: "slider")

        try? await Task.sleep(for: .milliseconds(400))
        #expect(commands == ["10"])
    }
}
