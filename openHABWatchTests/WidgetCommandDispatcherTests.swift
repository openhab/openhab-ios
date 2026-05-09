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

import Foundation
import OpenHABCore
@testable import openHABWatch
import Testing

private final class CommandRecorder {
    var commands: [String] = []
}

private func makeWidget(widgetId: String, recorder: CommandRecorder) -> OpenHABWidget {
    let item = OpenHABItem(
        name: "TestItem",
        type: "Switch",
        state: "OFF",
        link: "",
        label: nil,
        groupType: nil,
        stateDescription: nil,
        commandDescription: nil,
        members: [],
        category: nil,
        options: nil
    )
    let widget = OpenHABWidget(icon: "switch")
    widget.widgetId = widgetId
    widget.item = item
    widget.sendCommand = { _, command in
        recorder.commands.append(command ?? "")
    }
    return widget
}

struct WidgetCommandDispatcherTests {
    @Test("Immediate policy sends command once")
    @MainActor
    func immediatePolicySendsOnce() {
        let recorder = CommandRecorder()
        let widget = makeWidget(widgetId: "immediate", recorder: recorder)
        let sender = WidgetCommandDispatcher()

        sender.send("ON", for: widget, policy: .immediate)

        #expect(recorder.commands == ["ON"])
    }

    @Test("Debounce policy keeps only final command")
    @MainActor
    func debounceKeepsFinalCommand() async throws {
        let recorder = CommandRecorder()
        let widget = makeWidget(widgetId: "debounce", recorder: recorder)
        let sender = WidgetCommandDispatcher()

        sender.send("ON", for: widget, policy: .debounce(.milliseconds(80)))
        sender.send("OFF", for: widget, policy: .debounce(.milliseconds(80)))

        try await Task.sleep(for: .milliseconds(200))
        #expect(recorder.commands == ["OFF"])
    }

    @Test("Pending debounced command can be cancelled")
    @MainActor
    func cancelPendingPreventsDispatch() async throws {
        let recorder = CommandRecorder()
        let widget = makeWidget(widgetId: "cancel", recorder: recorder)
        let sender = WidgetCommandDispatcher()

        sender.send("ON", for: widget, policy: .debounce(.milliseconds(120)))
        sender.cancelPending(for: widget)

        try await Task.sleep(for: .milliseconds(220))
        #expect(recorder.commands.isEmpty)
    }

    @Test("Press and release commands dispatch in order")
    @MainActor
    func pressReleaseDispatchesInOrder() {
        let recorder = CommandRecorder()
        let widget = makeWidget(widgetId: "press-release", recorder: recorder)
        let sender = WidgetCommandDispatcher()

        sender.sendPress("UP", for: widget)
        sender.sendRelease("STOP", for: widget)

        #expect(recorder.commands == ["UP", "STOP"])
    }

    @Test("Item update dispatches command and ignores nil state")
    @MainActor
    func itemUpdateDispatchesAndSkipsNil() {
        let recorder = CommandRecorder()
        let widget = makeWidget(widgetId: "item-update", recorder: recorder)
        let sender = WidgetCommandDispatcher()

        sender.send(NumberState(value: 21), for: widget)
        sender.send(nil as NumberState?, for: widget)

        #expect(recorder.commands.count == 1)
        #expect(recorder.commands.first?.contains("21") == true)
    }
}
