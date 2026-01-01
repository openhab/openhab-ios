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

enum ActionMapper {
    /// Provides the standard on/off action options for dynamic option providers
    static var onOffOptions: [String] {
        [
            String(localized: "on").capitalized,
            String(localized: "off").capitalized
        ]
    }

    /// Provides on/off/toggle action options for dynamic option providers
    static var onOffToggleOptions: [String] {
        [
            String(localized: "on").capitalized,
            String(localized: "off").capitalized,
            String(localized: "toggle").capitalized
        ]
    }

    /// Maps a localized action label (e.g., "On", "Off", "Toggle") to an openHAB command (e.g., "ON", "OFF", "TOGGLE")
    /// - Parameter localizedAction: The localized action string from user input
    /// - Returns: The corresponding openHAB command, or nil if the action is not recognized
    static func command(from localizedAction: String) -> String? {
        let onLabel = String(localized: "on").capitalized
        let offLabel = String(localized: "off").capitalized
        let toggleLabel = String(localized: "toggle").capitalized

        let actionMap: [String: String] = [
            onLabel: "ON",
            offLabel: "OFF",
            toggleLabel: "TOGGLE"
        ]

        return actionMap[localizedAction]
    }
}
