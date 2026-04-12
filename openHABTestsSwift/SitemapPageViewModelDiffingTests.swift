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
import Combine
import OpenHABCore
import Testing

/// Tests that the row-input and widget-version pipelines avoid unnecessary
/// @Published writes when incoming data is unchanged.
@MainActor
@Suite
struct SitemapPageViewModelDiffingTests {
    // MARK: rowInputs diffing

    @Test
    func rebuildRowInputsProducesStableOutputForUnchangedWidgets() {
        let widgets = [makeTextWidget(widgetID: "w1", label: "Light"), makeTextWidget(widgetID: "w2", label: "Temp")]
        let viewModel = SitemapPageViewModel(title: "Test", widgets: widgets)

        let first = viewModel.rowInputs
        viewModel.rebuildRowInputs()
        let second = viewModel.rowInputs

        #expect(first == second)
    }

    @Test
    func rebuildRowInputsDoesNotFireObjectWillChangeWhenUnchanged() {
        let widgets = [makeTextWidget(widgetID: "w1", label: "Light")]
        let viewModel = SitemapPageViewModel(title: "Test", widgets: widgets)

        var changeCount = 0
        let cancellable = viewModel.objectWillChange.sink { changeCount += 1 }

        let countBefore = changeCount
        // Second rebuild with identical widgets — guard should suppress the assignment.
        viewModel.rebuildRowInputs()
        #expect(changeCount == countBefore)

        withExtendedLifetime(cancellable) {}
    }

    @Test
    func rebuildRowInputsFiresObjectWillChangeWhenWidgetsChange() {
        let widget = makeTextWidget(widgetID: "w1", label: "Light")
        let viewModel = SitemapPageViewModel(title: "Test", widgets: [widget])

        var changeCount = 0
        let cancellable = viewModel.objectWillChange.sink { changeCount += 1 }

        let countBefore = changeCount

        // Swap in a differently-labelled widget and rebuild.
        let changed = makeTextWidget(widgetID: "w1", label: "Updated")
        viewModel.currentPage = makePage(widgets: [changed])
        viewModel.rebuildRowInputs()

        #expect(changeCount > countBefore)

        withExtendedLifetime(cancellable) {}
    }

    @Test
    func rebuildRowInputsHandlesStructureChange() {
        let widgets = [makeTextWidget(widgetID: "w1", label: "One"), makeTextWidget(widgetID: "w2", label: "Two")]
        let viewModel = SitemapPageViewModel(title: "Test", widgets: widgets)

        #expect(viewModel.rowInputs.count == 2)

        viewModel.currentPage = makePage(widgets: [makeTextWidget(widgetID: "w1", label: "One")])
        viewModel.rebuildRowInputs()

        #expect(viewModel.rowInputs.count == 1)
    }

    // MARK: bumpWidgetVersions

    @Test
    func bumpWidgetVersionsDoesNotIncrementForIdenticalInputs() {
        let viewModel = SitemapPageViewModel(title: "Test", widgets: [makeTextWidget(widgetID: "w1", label: "Temp")])
        let inputs = viewModel.rowInputs
        let before = viewModel.widgetUpdateVersion(for: inputs[0].rowID)

        viewModel.bumpWidgetVersions(from: inputs, to: inputs)

        #expect(viewModel.widgetUpdateVersion(for: inputs[0].rowID) == before)
    }

    @Test
    func bumpWidgetVersionsIncrementsOnlyForChangedRow() {
        let w1 = makeTextWidget(widgetID: "w1", label: "Stable")
        let w2 = makeTextWidget(widgetID: "w2", label: "Changing")
        let viewModel = SitemapPageViewModel(title: "Test", widgets: [w1, w2])

        let oldInputs = viewModel.rowInputs

        // Rebuild with w2 changed.
        viewModel.currentPage = makePage(widgets: [w1, makeTextWidget(widgetID: "w2", label: "Updated")])
        viewModel.rebuildRowInputs()
        let newInputs = viewModel.rowInputs

        let v1Before = viewModel.widgetUpdateVersion(for: oldInputs[0].rowID)
        let v2Before = viewModel.widgetUpdateVersion(for: oldInputs[1].rowID)

        viewModel.bumpWidgetVersions(from: oldInputs, to: newInputs)

        #expect(viewModel.widgetUpdateVersion(for: newInputs[0].rowID) == v1Before, "Stable widget version must not change")
        #expect(viewModel.widgetUpdateVersion(for: newInputs[1].rowID) > v2Before, "Changed widget version must increment")
    }

    @Test
    func bumpWidgetVersionsIncrementsAllRowsOnStructureChange() {
        let viewModel = SitemapPageViewModel(
            title: "Test",
            widgets: [makeTextWidget(widgetID: "w1", label: "One")]
        )
        let oldInputs = viewModel.rowInputs

        viewModel.currentPage = makePage(widgets: [
            makeTextWidget(widgetID: "w1", label: "One"),
            makeTextWidget(widgetID: "w2", label: "Two")
        ])
        viewModel.rebuildRowInputs()
        let newInputs = viewModel.rowInputs

        let v1Before = viewModel.widgetUpdateVersion(for: oldInputs[0].rowID)
        let v2Before = 0

        viewModel.bumpWidgetVersions(from: oldInputs, to: newInputs)

        // Count changed — all new rows should get a bump.
        #expect(viewModel.widgetUpdateVersion(for: newInputs[0].rowID) > v1Before)
        #expect(viewModel.widgetUpdateVersion(for: newInputs[1].rowID) > v2Before)
    }

    @Test
    func bumpWidgetVersionsHandlesRepeatedWidgetIDsIndependently() {
        let oldWidgets = [
            makeTextWidget(widgetID: "dup", label: "One"),
            makeTextWidget(widgetID: "dup", label: "Two")
        ]
        let viewModel = SitemapPageViewModel(title: "Test", widgets: oldWidgets)
        let oldInputs = viewModel.rowInputs

        viewModel.currentPage = makePage(widgets: [
            makeTextWidget(widgetID: "dup", label: "One"),
            makeTextWidget(widgetID: "dup", label: "Updated")
        ])
        viewModel.rebuildRowInputs()
        let newInputs = viewModel.rowInputs

        let firstBefore = viewModel.widgetUpdateVersion(for: oldInputs[0].rowID)
        let secondBefore = viewModel.widgetUpdateVersion(for: oldInputs[1].rowID)

        viewModel.bumpWidgetVersions(from: oldInputs, to: newInputs)

        #expect(viewModel.widgetUpdateVersion(for: newInputs[0].rowID) == firstBefore)
        #expect(viewModel.widgetUpdateVersion(for: newInputs[1].rowID) > secondBefore)
    }
}

// MARK: - Helpers

private extension SitemapPageViewModelDiffingTests {
    func makeTextWidget(widgetID: String, label: String) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = widgetID
        widget.type = .text
        widget.label = label
        return widget
    }

    func makePage(widgets: [OpenHABWidget]) -> OpenHABPage {
        OpenHABPage(pageId: "p1", title: "Test", link: "", leaf: false, widgets: widgets, icon: "")
    }
}
