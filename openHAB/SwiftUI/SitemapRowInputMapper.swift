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

enum SitemapRowInputMapper {
    static func map(pageKey: String, widgets: [OpenHABWidget]) -> [SitemapRowInput] {
        var occurrenceByWidgetID: [String: Int] = [:]
        return widgets.map { widget in
            occurrenceByWidgetID[widget.widgetId, default: 0] += 1
            let occurrence = occurrenceByWidgetID[widget.widgetId]!
            let rowID = RowID(pageKey: pageKey, widgetId: widget.widgetId, occurrence: occurrence)
            return map(widget: widget, rowID: rowID)
        }
    }

    static func map(widget: OpenHABWidget, rowID: RowID) -> SitemapRowInput {
        // Preserve legacy navigation behavior for linked-page rows.
        // These rows are still rendered through EmbeddingRowView, which owns NavigationLink wiring.
        if widget.linkedPage != nil {
            return .generic(rowID, GenericRowInput.from(widget: widget))
        }

        switch widget.renderingKind {
        case .slider:
            return SitemapRowInput.slider(rowID, SliderRowInput.from(widget: widget))
        case .selection:
            return SitemapRowInput.selection(rowID, SelectionRowInput.from(widget: widget))
        case .segmentedSwitch:
            return SitemapRowInput.segmented(rowID, SegmentedRowInput.from(widget: widget))
        case .frame:
            return SitemapRowInput.frame(rowID, FrameRowInput.from(widget: widget))
        case .text:
            return SitemapRowInput.text(rowID, TextRowInput.from(widget: widget))
        case .setpoint:
            return SitemapRowInput.setpoint(rowID, SetpointRowInput.from(widget: widget))
        case .rollershutterSwitch:
            return SitemapRowInput.rollershutter(rowID, RollershutterRowInput.from(widget: widget))
        case .toggleSwitch:
            return SitemapRowInput.toggle(rowID, ToggleRowInput.from(widget: widget))
        case .dateInput, .textInput:
            return SitemapRowInput.input(rowID, InputRowInput.from(widget: widget))
        case .colorPicker:
            return SitemapRowInput.colorPicker(rowID, ColorPickerRowInput.from(widget: widget))
        case .image, .chart, .video, .webview, .mapview:
            return SitemapRowInput.media(rowID, MediaRowInput.from(widget: widget))
        case .colorTemperaturePicker:
            return SitemapRowInput.colorTemperature(rowID, ColorTemperatureRowInput.from(widget: widget))
        case .buttonGrid:
            return SitemapRowInput.buttonGrid(rowID, ButtonGridRowInput.from(widget: widget))
        case .generic:
            return SitemapRowInput.generic(rowID, GenericRowInput.from(widget: widget))
        }
    }
}
