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

import AppIntents
import Foundation

enum SwitchAction: String, AppEnum {
    case on = "ON"
    case off = "OFF"
    case toggle = "TOGGLE"

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Switch Action", defaultValue: "Switch Action")
    )

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .on: DisplayRepresentation(
            title: LocalizedStringResource("On", defaultValue: "On"),
            synonyms: [
                LocalizedStringResource("Turn on", defaultValue: "Turn on"),
                LocalizedStringResource("Switch on", defaultValue: "Switch on"),
                LocalizedStringResource("Enable", defaultValue: "Enable")
            ]
        ),
        .off: DisplayRepresentation(
            title: LocalizedStringResource("Off", defaultValue: "Off"),
            synonyms: [
                LocalizedStringResource("Turn off", defaultValue: "Turn off"),
                LocalizedStringResource("Switch off", defaultValue: "Switch off"),
                LocalizedStringResource("Disable", defaultValue: "Disable")
            ]
        ),
        .toggle: DisplayRepresentation(
            title: LocalizedStringResource("Toggle", defaultValue: "Toggle"),
            synonyms: [
                LocalizedStringResource("Flip", defaultValue: "Flip"),
                LocalizedStringResource("Switch", defaultValue: "Switch"),
                LocalizedStringResource("Change", defaultValue: "Change")
            ]
        )
    ]
}

extension SwitchAction: CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .on: "On"
        case .off: "Off"
        case .toggle: "Toggle"
        }
    }
}
