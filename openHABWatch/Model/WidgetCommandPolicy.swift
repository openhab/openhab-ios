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
import OpenHABCore

enum WidgetCommandPolicy: Sendable {
    case immediate
    case debounce(Duration)
}

enum WidgetCommandDefaults {
    static let slider: WidgetCommandPolicy = .debounce(.milliseconds(500))
    static let immediate: WidgetCommandPolicy = .immediate

    static func policy(for widget: OpenHABWidget) -> WidgetCommandPolicy {
        switch widget.type {
        case .slider:
            slider
        default:
            immediate
        }
    }
}
