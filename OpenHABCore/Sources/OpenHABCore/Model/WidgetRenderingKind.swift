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
