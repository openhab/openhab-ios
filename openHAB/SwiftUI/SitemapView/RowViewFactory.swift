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
        switch widget.renderingKind {
        case .segmentedSwitch:
            SegmentedRowView(widget: widget)
        case .toggleSwitch:
            SwitchRowView(widget: widget)
        case .rollershutterSwitch:
            RollershutterRowView(widget: widget)
        case .slider: // SliderRowView also handles switchSupport
            SliderRowView(widget: widget)
        case .dateInput:
            DatePickerInputRowView(widget: widget)
        case .textInput:
            TextInputRowView(widget: widget)
        case .text:
            TextRowView(widget: widget)
        case .frame:
            FrameRowView(widget: widget)
        case .setpoint:
            SetpointRowView(widget: widget)
        case .selection:
            SelectionRowView(widget: widget)
        case .colorPicker:
            ColorPickerRowView(widget: widget)
        case .image, .chart:
            ImageRowView(widget: widget)
        case .video:
            VideoRowView(widget: widget)
        case .webview:
            WidgetWebViewContainer(widget: widget)
        case .mapview:
            MapRowView(widget: widget)
        case .colorTemperaturePicker:
            ColorTemperaturePickerRowView(widget: widget)
        case .buttonGrid:
            ButtonGridRowView(widget: widget)
        case .generic:
            GenericRowView(widget: widget)
        }
    }
}
