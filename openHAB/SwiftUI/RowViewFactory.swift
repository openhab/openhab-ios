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

enum RowViewFactory {
    @MainActor @ViewBuilder
    static func view(for widget: OpenHABWidget) -> some View {
        switch widget.type {
        case .switchWidget:
            if !widget.mappings.isEmpty {
                SegmentedRowView(widget: widget)
            } else if widget.item?.isOfTypeOrGroupType(.switchItem) ?? false {
                SwitchRowView(widget: widget)
            } else if widget.item?.isOfTypeOrGroupType(.rollershutter) ?? false {
                RollershutterRowView(widget: widget)
            } else if !widget.mappingsOrItemOptions.isEmpty {
                SegmentedRowView(widget: widget)
            } else {
                SwitchRowView(widget: widget)
            }
        case .slider: // SliderRowView also handles switchSupport
            SliderRowView(widget: widget)
        case .input:
            if [.date, .time, .dateTime].contains(widget.inputHint) {
                DatePickerInputRowView(widget: widget)
            } else {
                TextInputRowView(widget: widget)
            }
        case .text:
            TextRowView(widget: widget)
        case .frame:
            FrameRowView(widget: widget)
        case .setpoint:
            SetpointRowView(widget: widget)
        case .selection:
            SelectionRowView(widget: widget)
        case .colorpicker:
            ColorPickerRowView(widget: widget)
        case .image, .chart:
            ImageRowView(widget: widget)
        case .video:
            VideoRowView(widget: widget)
        case .webview:
            WidgetWebViewContainer(widget: widget)
        case .mapview:
            MapRowView(widget: widget)
        case .colortemperaturepicker:
            ColorTemperaturePickerRowView(widget: widget)
        case .buttongrid:
            ButtonGridRowView(widget: widget)
        case .group, .defaultWidget, .button, .unknown:
            GenericRowView(widget: widget)
        }
    }
}
