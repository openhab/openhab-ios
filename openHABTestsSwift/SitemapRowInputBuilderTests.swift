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

@Suite
struct WidgetMappingSnapshotDisplayStateTests {
    @Test
    func labelOnlyInBracketsDoesNotLeakIntoLabelText() {
        // When no sitemap label is defined, the server returns only the formatted
        // value in brackets, e.g. "[Uitgeschakeld]". labelText must be empty so the
        // value is shown trailing-aligned, not duplicated as "[Uitgeschakeld] Uitgeschakeld".
        let snapshot = makeSnapshot(label: "[Uitgeschakeld]")
        let display = snapshot.displayState
        #expect(display.labelText == "")
        #expect(display.labelValue == "Uitgeschakeld")
    }

    @Test
    func normalLabelWithValueParsesCorrectly() {
        let snapshot = makeSnapshot(label: "Kitchen Light [On]")
        let display = snapshot.displayState
        #expect(display.labelText == "Kitchen Light")
        #expect(display.labelValue == "On")
    }

    @Test
    func emptyLabelProducesEmptyLabelText() {
        let snapshot = makeSnapshot(label: "")
        let display = snapshot.displayState
        #expect(display.labelText == "")
        #expect(display.labelValue == nil)
    }

    private func makeSnapshot(label: String) -> WidgetMappingSnapshot {
        let widget = OpenHABWidget()
        widget.widgetId = "test"
        widget.type = .text
        widget.label = label
        return WidgetMappingSnapshot(widget: widget)
    }
}

@Suite
struct SitemapRowInputBuilderTests {
    @Test
    func incrementalRebuildReusesUnchangedRows() {
        let widget1 = makeTextWidget(widgetID: "text-1", label: "Kitchen")
        let widget2 = makeTextWidget(widgetID: "text-2", label: "Hallway")
        let pageKey = "default|home"

        let initial = buildInitial(pageKey: pageKey, widgets: [widget1, widget2])

        widget2.label = "Hallway Updated"
        let updated = buildIncrementally(pageKey: pageKey, widgets: [widget1, widget2], previous: initial)

        #expect(updated.reusedInputCount == 1)
        #expect(updated.inputs[0] == initial.inputs[0])
        #expect(updated.inputs[1] != initial.inputs[1])
    }

    @Test
    func incrementalRebuildTracksNestedButtonGridChanges() {
        let childA = makeButtonWidget(widgetID: "button-a", label: "A")
        let childB = makeButtonWidget(widgetID: "button-b", label: "B")
        let buttonGrid = makeButtonGridWidget(widgetID: "grid", children: [childA, childB])
        let pageKey = "default|buttons"

        let initial = buildInitial(pageKey: pageKey, widgets: [buttonGrid])

        childB.label = "B Updated"
        let updated = buildIncrementally(pageKey: pageKey, widgets: [buttonGrid], previous: initial)

        #expect(updated.reusedInputCount == 0)
        #expect(updated.inputs[0] != initial.inputs[0])
    }

    @Test
    func incrementalRebuildFallsBackWhenCountsChange() {
        let widget = makeTextWidget(widgetID: "text-1", label: "Kitchen")
        let pageKey = "default|home"

        let initial = buildInitial(pageKey: pageKey, widgets: [widget])

        let extra = makeTextWidget(widgetID: "text-2", label: "Hallway")
        let updated = buildIncrementally(pageKey: pageKey, widgets: [widget, extra], previous: initial)

        #expect(updated.reusedInputCount == 0)
        #expect(updated.inputs.count == 2)
    }
}

private extension SitemapRowInputBuilderTests {
    func buildInitial(pageKey: String, widgets: [OpenHABWidget]) -> SnapshotRowInputBuildResult {
        SitemapRowInputSnapshotBuilder.build(pageKey: pageKey, widgets: widgets.map(WidgetMappingSnapshot.init))
    }

    func buildIncrementally(pageKey: String,
                            widgets: [OpenHABWidget],
                            previous: SnapshotRowInputBuildResult) -> SnapshotRowInputBuildResult {
        SitemapRowInputSnapshotBuilder.buildIncrementally(
            pageKey: pageKey,
            widgets: widgets.map(WidgetMappingSnapshot.init),
            previousRenderKeys: previous.renderKeys,
            previousInputs: previous.inputs,
            previousRowIDs: previous.rowIDs
        )
    }

    func makeTextWidget(widgetID: String, label: String) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = widgetID
        widget.type = .text
        widget.label = label
        return widget
    }

    func makeButtonGridWidget(widgetID: String, children: [OpenHABWidget]) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = widgetID
        widget.type = .buttongrid
        widget.widgets = children
        return widget
    }

    func makeButtonWidget(widgetID: String, label: String) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = widgetID
        widget.type = .button
        widget.label = label
        widget.row = 1
        widget.column = 1
        return widget
    }
}
