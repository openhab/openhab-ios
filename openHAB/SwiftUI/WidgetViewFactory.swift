// Copyright (c) 2010-2025 Contributors to the openHAB project
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

enum WidgetViewFactory {
    @ViewBuilder
    static func view(for widget: OpenHABWidget) -> some View {
        switch widget.type {
        case .switchWidget:
            if !widget.mappings.isEmpty {
                WidgetSegmentedView(widget: widget)
            } else if widget.item?.isOfTypeOrGroupType(.switchItem) ?? false {
                WidgetSwitchView(widget: widget)
            } else if widget.item?.isOfTypeOrGroupType(.rollershutter) ?? false {
                WidgetRollershutterView(widget: widget)
            } else if !widget.mappingsOrItemOptions.isEmpty {
                WidgetSegmentedView(widget: widget)
            } else {
                WidgetSwitchView(widget: widget)
            }
        case .slider:
            if widget.switchSupport {
                WidgetSliderWithSwitchView(widget: widget)
            } else {
                WidgetSliderView(widget: widget)
            }
        case .input:
            if [.date, .time, .datetime].contains(widget.inputHint) {
                WidgetDatePickerInputView(widget: widget)
            } else {
                WidgetTextInputView(widget: widget)
            }
        case .text:
            WidgetTextView(widget: widget)
        case .frame:
            EmptyView() // ignore frames
        case .setpoint:
            WidgetSetpointView(widget: widget)
        case .selection:
            WidgetSelectionView(widget: widget)
        case .colorpicker:
            WidgetColorPickerView(widget: widget)
        case .image, .chart:
            WidgetImageView(widget: widget)
        case .video:
            WidgetVideoView(widget: widget)
        case .webview:
            WidgetWebViewContainer(widget: widget)
        case .mapview:
            WidgetMapView(widget: widget)
        case .group, .defaultWidget, .unknown:
            WidgetGenericView(widget: widget)
        }
    }
}
