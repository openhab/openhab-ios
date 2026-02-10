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

enum WidgetRowFactory {
    @MainActor
    @ViewBuilder
    static func make(widget: OpenHABWidget, settings: AppSettings) -> some View {
        switch widget.type {
        case .switchWidget:
            if !widget.mappings.isEmpty {
                SegmentRow(widget: widget)
            } else if widget.item?.isOfTypeOrGroupType(.switchItem) ?? false {
                SwitchRow(widget: widget, effectiveState: widget.state.isEmpty ? (widget.item?.state ?? "") : widget.state)
            } else if widget.item?.isOfTypeOrGroupType(.rollershutter) ?? false {
                RollershutterRow(widget: widget)
            } else if !widget.mappingsOrItemOptions.isEmpty {
                SegmentRow(widget: widget)
            } else {
                SwitchRow(widget: widget, effectiveState: widget.state.isEmpty ? (widget.item?.state ?? "") : widget.state)
            }
        case .slider:
            SliderRow(widget: widget)
        case .setpoint:
            SetpointRow(widget: widget)
        case .frame:
            FrameRow(title: widget.labelText ?? "")
        case .text:
            TextRow(widget: widget, hasLinkedPage: widget.linkedPage != nil)
        case .image:
            if widget.item != nil {
                ImageRawRow(widget: widget)
            } else {
                EquatableView(content: ImageRow(url: URL(string: widget.url), refresh: widget.refresh))
            }
        case .chart:
            let url = Endpoint.chart(
                rootUrl: settings.openHABRootUrl,
                period: widget.period,
                type: widget.item?.type ?? .none,
                service: widget.service,
                name: widget.item?.name,
                legend: widget.legend,
                theme: .dark,
                forceAsItem: widget.forceAsItem
            ).url
            EquatableView(content: ImageRow(url: url, refresh: widget.refresh))
        case .mapview:
            MapViewRow(widget: widget)
        case .colorpicker:
            ColorPickerRow(widget: widget)
        case .selection:
            SelectionRow(
                widget: widget,
                mappings: widget.mappingsOrItemOptions,
                title: widget.labelText ?? "Select",
                initialSelectedIndex: widget.mappingIndex(byCommand: widget.item?.state).map { Int($0) },
                labelValue: widget.labelValue
            )
        case .video, .webview, .input, .colortemperaturepicker, .buttongrid:
            // Not yet implemented for watchOS
            GenericRow(widget: widget)
        case .group, .defaultWidget, .button, .unknown:
            GenericRow(widget: widget)
        }
    }
}
