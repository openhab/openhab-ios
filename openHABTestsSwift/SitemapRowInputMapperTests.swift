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
import OpenHABCore
import Testing

struct SitemapRowInputMapperTests {
    @Test
    func linkedPageWidgetsAlwaysMapToLinked() {
        let widgets = [
            makeSliderWidget(widgetID: "slider"),
            makeSetpointWidget(widgetID: "setpoint"),
            makeSegmentedSwitchWidget(widgetID: "segmented"),
            makeToggleSwitchWidget(widgetID: "toggle"),
            makeRollershutterSwitchWidget(widgetID: "rollershutter"),
            makeTextInputWidget(widgetID: "textInput"),
            makeDateInputWidget(widgetID: "dateInput"),
            makeColorPickerWidget(widgetID: "colorPicker"),
            makeButtonGridWidget(widgetID: "buttonGrid"),
            makeTextWidget(widgetID: "text"),
            makeFrameWidget(widgetID: "frame")
        ]

        for (index, widget) in widgets.enumerated() {
            widget.linkedPage = makeLinkedPage()
            let rowID = RowID(pageKey: "testPage", widgetId: widget.widgetId, occurrence: index + 1)
            let mapped = SitemapRowInputMapper.map(widget: widget, rowID: rowID)

            guard case let .linked(mappedRowID, input) = mapped else {
                #expect(Bool(false), "Expected .linked for linked widget \(widget.widgetId)")
                continue
            }
            #expect(mappedRowID == rowID)
            #expect(input.widgetId == widget.widgetId)
            #expect(input.linkedPageLink == "https://example.invalid/linked")
            #expect(input.linkedPageTitle == "Linked")
        }
    }

    @Test
    func nonLinkedWidgetUsesSpecificMapping() {
        let widget = makeSliderWidget(widgetID: "slider")
        let rowID = RowID(pageKey: "testPage", widgetId: widget.widgetId, occurrence: 1)
        let mapped = SitemapRowInputMapper.map(widget: widget, rowID: rowID)

        guard case let .slider(mappedRowID, input) = mapped else {
            #expect(Bool(false), "Expected .slider for non-linked slider widget")
            return
        }

        #expect(mappedRowID == rowID)
        #expect(input.widgetId == widget.widgetId)
    }

    @Test
    func snapshotMappingMatchesWidgetMapping() {
        let widgets = [
            makeSliderWidget(widgetID: "slider"),
            makeSetpointWidget(widgetID: "setpoint"),
            makeSegmentedSwitchWidget(widgetID: "segmented"),
            makeToggleSwitchWidget(widgetID: "toggle"),
            makeRollershutterSwitchWidget(widgetID: "rollershutter"),
            makeTextInputWidget(widgetID: "textInput"),
            makeDateInputWidget(widgetID: "dateInput"),
            makeColorPickerWidget(widgetID: "colorPicker"),
            makeButtonGridWidget(widgetID: "buttonGrid"),
            makeTextWidget(widgetID: "text"),
            makeFrameWidget(widgetID: "frame"),
            makeVideoWidget(
                widgetID: "video",
                url: "http://default.example.invalid/video.m3u8",
                itemState: "http://camera.example.invalid/live.m3u8"
            )
        ]

        for (index, widget) in widgets.enumerated() {
            let rowID = RowID(pageKey: "testPage", widgetId: widget.widgetId, occurrence: index + 1)
            let mapped = SitemapRowInputMapper.map(widget: widget, rowID: rowID)
            let snapshotMapped = SitemapRowInputMapper.map(snapshot: WidgetMappingSnapshot(widget: widget), rowID: rowID)
            #expect(snapshotMapped == mapped)
        }
    }

    @Test
    func videoWidgetUsesItemStateURLBeforeConfiguredURL() {
        let widget = makeVideoWidget(
            widgetID: "video",
            url: "http://default.example.invalid/video.m3u8",
            itemState: "http://camera.example.invalid/live.m3u8"
        )
        let input = MediaRowInput.from(widget: widget)

        #expect(input.url == "http://camera.example.invalid/live.m3u8")
    }

    @Test
    func videoSnapshotUsesItemStateURLBeforeConfiguredURL() {
        let widget = makeVideoWidget(
            widgetID: "video",
            url: "dummy",
            itemState: "http://camera.example.invalid/live.m3u8"
        )
        let rowID = RowID(pageKey: "testPage", widgetId: widget.widgetId, occurrence: 1)
        let input = SitemapRowInputMapper.map(snapshot: WidgetMappingSnapshot(widget: widget), rowID: rowID)

        guard case let .media(_, mediaInput) = input else {
            Issue.record("Expected media row input")
            return
        }
        #expect(mediaInput.url == "http://camera.example.invalid/live.m3u8")
    }

    @Test
    func videoWidgetFallsBackToConfiguredURLWhenItemStateIsNotURL() {
        let widget = makeVideoWidget(
            widgetID: "video",
            url: "http://default.example.invalid/video.m3u8",
            itemState: "OFF"
        )
        let input = MediaRowInput.from(widget: widget)

        #expect(input.url == "http://default.example.invalid/video.m3u8")
    }
}

private extension SitemapRowInputMapperTests {
    func makeLinkedPage() -> OpenHABPage {
        OpenHABPage(
            pageId: "linked",
            title: "Linked",
            link: "https://example.invalid/linked",
            leaf: false,
            widgets: [],
            icon: ""
        )
    }

    func makeItem(name: String, type: String, state: String = "0") -> OpenHABItem {
        OpenHABItem(
            name: name,
            type: type,
            state: state,
            link: "",
            label: nil,
            groupType: nil,
            stateDescription: nil,
            commandDescription: nil,
            members: [],
            category: nil,
            options: nil
        )
    }

    func makeSliderWidget(widgetID: String) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = widgetID
        widget.type = .slider
        widget.item = makeItem(name: "SliderItem", type: "Dimmer", state: "50")
        return widget
    }

    func makeSetpointWidget(widgetID: String) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = widgetID
        widget.type = .setpoint
        widget.item = makeItem(name: "SetpointItem", type: "Number", state: "21")
        return widget
    }

    func makeSegmentedSwitchWidget(widgetID: String) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = widgetID
        widget.type = .switchWidget
        widget.item = makeItem(name: "SwitchItem", type: "Switch", state: "OFF")
        widget.mappings = [OpenHABWidgetMapping(command: "ON", label: "On")]
        return widget
    }

    func makeToggleSwitchWidget(widgetID: String) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = widgetID
        widget.type = .switchWidget
        widget.item = makeItem(name: "ToggleItem", type: "Switch", state: "OFF")
        return widget
    }

    func makeRollershutterSwitchWidget(widgetID: String) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = widgetID
        widget.type = .switchWidget
        widget.item = makeItem(name: "ShutterItem", type: "Rollershutter", state: "50")
        return widget
    }

    func makeTextInputWidget(widgetID: String) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = widgetID
        widget.type = .input
        widget.inputHint = .text
        widget.item = makeItem(name: "TextInputItem", type: "String", state: "abc")
        return widget
    }

    func makeDateInputWidget(widgetID: String) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = widgetID
        widget.type = .input
        widget.inputHint = .dateTime
        widget.item = makeItem(name: "DateInputItem", type: "DateTime", state: "2026-01-01T12:00:00")
        return widget
    }

    func makeColorPickerWidget(widgetID: String) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = widgetID
        widget.type = .colorpicker
        widget.item = makeItem(name: "ColorItem", type: "Color", state: "0,0,0")
        return widget
    }

    func makeButtonGridWidget(widgetID: String) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = widgetID
        widget.type = .buttongrid
        widget.item = makeItem(name: "ButtonGridItem", type: "String", state: "")
        widget.mappings = [OpenHABWidgetMapping(command: "ON", label: "On")]
        return widget
    }

    func makeTextWidget(widgetID: String) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = widgetID
        widget.type = .text
        return widget
    }

    func makeFrameWidget(widgetID: String) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = widgetID
        widget.type = .frame
        return widget
    }

    func makeVideoWidget(widgetID: String, url: String, itemState: String) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = widgetID
        widget.type = .video
        widget.url = url
        widget.item = makeItem(name: "VideoItem", type: "String", state: itemState)
        return widget
    }
}
