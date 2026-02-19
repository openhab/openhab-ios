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
        switch widget.renderingKind {
        case .slider:
            .slider(rowID, SliderRowInput.from(widget: widget))
        case .selection:
            .selection(rowID, SelectionRowInput.from(widget: widget))
        case .segmentedSwitch:
            .segmented(rowID, SegmentedRowInput.from(widget: widget))
        case .frame:
            .frame(rowID, BasicWidgetRowInput.from(widget: widget))
        case .text:
            .text(rowID, BasicWidgetRowInput.from(widget: widget))
        case .setpoint:
            .setpoint(rowID, BasicWidgetRowInput.from(widget: widget))
        case .rollershutterSwitch:
            .rollershutter(rowID, BasicWidgetRowInput.from(widget: widget))
        case .toggleSwitch:
            .toggle(rowID, BasicWidgetRowInput.from(widget: widget))
        case .dateInput, .textInput:
            .input(rowID, BasicWidgetRowInput.from(widget: widget))
        case .colorPicker:
            .colorPicker(rowID, BasicWidgetRowInput.from(widget: widget))
        case .image, .chart, .video, .webview, .mapview:
            .media(rowID, BasicWidgetRowInput.from(widget: widget))
        case .colorTemperaturePicker:
            .colorTemperature(rowID, BasicWidgetRowInput.from(widget: widget))
        case .buttonGrid:
            .buttonGrid(rowID, BasicWidgetRowInput.from(widget: widget))
        case .generic:
            .generic(rowID, BasicWidgetRowInput.from(widget: widget))
        }
    }
}
