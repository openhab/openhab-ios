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

struct WidgetRenderingKindTests {
    @Test
    func switchWithMappingsUsesSegmentedKind() {
        let widget = makeWidget(type: .switchWidget, itemType: "Switch")
        widget.mappings = [OpenHABWidgetMapping(command: "ON", label: "On")]

        #expect(widget.renderingKind == .segmentedSwitch)
    }

    @Test
    func switchWithSwitchItemUsesToggleKind() {
        let widget = makeWidget(type: .switchWidget, itemType: "Switch")

        #expect(widget.renderingKind == .toggleSwitch)
    }

    @Test
    func switchWithRollershutterItemUsesRollershutterKind() {
        let widget = makeWidget(type: .switchWidget, itemType: "Rollershutter")

        #expect(widget.renderingKind == .rollershutterSwitch)
    }

    @Test
    func inputDateHintUsesDateInputKind() {
        let widget = makeWidget(type: .input, itemType: "String")
        widget.inputHint = .dateTime

        #expect(widget.renderingKind == .dateInput)
    }

    @Test
    func inputTextHintUsesTextInputKind() {
        let widget = makeWidget(type: .input, itemType: "String")
        widget.inputHint = .text

        #expect(widget.renderingKind == .textInput)
    }

    private func makeWidget(type: OpenHABWidget.WidgetType, itemType: String) -> OpenHABWidget {
        let item = OpenHABItem(
            name: "Item",
            type: itemType,
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
        let widget = OpenHABWidget()
        widget.type = type
        widget.item = item
        return widget
    }
}
