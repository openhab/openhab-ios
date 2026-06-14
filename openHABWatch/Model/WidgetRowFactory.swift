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
        let displayState = widget.displayState
        let stateToken = displayState.effectiveState

        switch widget.renderingKind {
        case .segmentedSwitch:
            SegmentRow(widget: widget, stateToken: stateToken)
        case .toggleSwitch:
            SwitchRow(widget: widget, stateToken: stateToken)
        case .rollershutterSwitch:
            RollershutterRow(widget: widget)
        case .slider:
            SliderRow(widget: widget, stateToken: stateToken)
        case .setpoint:
            SetpointRow(widget: widget, stateToken: stateToken)
        case .frame:
            FrameRow(title: displayState.labelText)
        case .text:
            TextRow(widget: widget, hasLinkedPage: widget.linkedPage != nil)
        case .image:
            let payload = widget.mediaImageDescriptor.resolveImagePayload(rootUrl: settings.openHABRootUrl)
            switch payload {
            case let .embedded(data):
                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            case let .link(url):
                EquatableView(content: ImageRow(url: url, refresh: widget.refresh))
            case .empty:
                EquatableView(content: ImageRow(url: nil, refresh: widget.refresh))
            }
        case .chart:
            let payload = widget.mediaImageDescriptor.resolveImagePayload(
                rootUrl: settings.openHABRootUrl,
                chartStyle: .dark
            )
            let chartURL: URL? = if case let .link(url) = payload { url } else { nil }
            EquatableView(content: ImageRow(url: chartURL, refresh: widget.refresh))
        case .mapview:
            MapViewRow(widget: widget)
        case .colorPicker:
            ColorPickerRow(widget: widget, stateToken: stateToken)
        case .selection:
            SelectionRow(
                widget: widget,
                mappings: displayState.mappings,
                title: displayState.labelText.isEmpty ? "Select" : displayState.labelText,
                initialSelectedIndex: displayState.selectedIndex,
                labelValue: displayState.labelValue
            )
        case .video, .webview, .dateInput, .textInput, .colorTemperaturePicker, .buttonGrid:
            // Not yet implemented for watchOS
            GenericRow(widget: widget)
        case .generic:
            GenericRow(widget: widget)
        }
    }
}
