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
    public static let slider: WidgetCommandPolicy = .debounce(.milliseconds(500))
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
    /// Dispatches only when phase is `.release`.
    case finalOnly
    /// Dispatches only for `.press` and `.release` phases.
    case pressRelease
}

/// A discrete command held for user confirmation before it's actually sent. Shared between the
/// iOS and watchOS apps: each presents this as an alert; confirming runs `onConfirm`, cancelling
/// just discards it.
@MainActor
public struct PendingCommandConfirmation: Identifiable {
    public let id = UUID()
    public let message: String
    public let onConfirm: () -> Void

    public init(message: String, onConfirm: @escaping () -> Void) {
        self.message = message
        self.onConfirm = onConfirm
    }
}
