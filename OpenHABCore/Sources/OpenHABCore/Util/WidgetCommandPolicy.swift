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

public enum WidgetCommandDefaults {
    /// Pause-to-send policy used by the watch slider and the color-temperature picker.
    /// The sitemap slider sends live updates with ``realtimeSlider`` instead.
    public static let slider: WidgetCommandPolicy = .debounce(.milliseconds(500))
    /// Real-time slider drags. The first value is sent immediately, then the latest
    /// value is sent on this interval while the thumb keeps moving.
    public static let realtimeSlider: WidgetCommandPolicy = .throttle(.milliseconds(500))
    public static let colorPicker: WidgetCommandPolicy = .debounce(.milliseconds(200))
    public static let immediate: WidgetCommandPolicy = .immediate
    public static let finalOnly: WidgetCommandPolicy = .finalOnly
    public static let pressRelease: WidgetCommandPolicy = .pressRelease

    public static func policy(for widget: OpenHABWidget) -> WidgetCommandPolicy {
        switch widget.type {
        case .slider:
            slider
        case .colorpicker:
            colorPicker
        default:
            immediate
        }
    }
}

public enum WidgetCommandPhase: Sendable {
    case press
    case change
    case release
}

public enum WidgetCommandPolicy: Sendable {
    case immediate
    case debounce(Duration)
    /// Sends the first change immediately, then the newest change once per interval
    /// while newer values keep arriving.
    case throttle(Duration)
    /// Dispatches only when phase is `.release`.
    case finalOnly
    /// Dispatches only for `.press` and `.release` phases.
    case pressRelease
}
