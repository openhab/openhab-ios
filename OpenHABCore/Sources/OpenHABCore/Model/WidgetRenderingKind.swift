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

import Foundation

public enum WidgetRenderingKind: Sendable {
    case segmentedSwitch
    case toggleSwitch
    case rollershutterSwitch
    case slider
    case dateInput
    case textInput
    case text
    case frame
    case setpoint
    case selection
    case colorPicker
    case image
    case chart
    case video
    case webview
    case mapview
    case colorTemperaturePicker
    case buttonGrid
    case generic
}

public extension OpenHABWidget {
    var renderingKind: WidgetRenderingKind {
        switch type {
        case .switchWidget:
            if !mappings.isEmpty {
                return .segmentedSwitch
            }
            if item?.isOfTypeOrGroupType(.switchItem) ?? false {
                return .toggleSwitch
            }
            if item?.isOfTypeOrGroupType(.rollershutter) ?? false {
                return .rollershutterSwitch
            }
            if !mappingsOrItemOptions.isEmpty {
                return .segmentedSwitch
            }
            return .toggleSwitch
        case .slider:
            return .slider
        case .input:
            if [.date, .time, .dateTime].contains(inputHint) {
                return .dateInput
            }
            return .textInput
        case .text:
            return .text
        case .frame:
            return .frame
        case .setpoint:
            return .setpoint
        case .selection:
            return .selection
        case .colorpicker:
            return .colorPicker
        case .image:
            return .image
        case .chart:
            return .chart
        case .video:
            return .video
        case .webview:
            return .webview
        case .mapview:
            return .mapview
        case .colortemperaturepicker:
            return .colorTemperaturePicker
        case .buttongrid:
            return .buttonGrid
        case .group, .defaultWidget, .button, .unknown:
            return .generic
        }
    }
}
