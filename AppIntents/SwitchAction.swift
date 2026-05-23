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

@available(watchOS, unavailable)
@available(iOS 17.0, macOS 14.0, *)
enum SwitchAction: String, AppEnum {
    case on = "ON"
    case off = "OFF"
    case toggle = "TOGGLE"

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Switch Action")

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .on: "On",
        .off: "Off",
        .toggle: "Toggle"
    ]
}

@available(watchOS, unavailable)
@available(iOS 17.0, macOS 14.0, *)
extension SwitchAction: CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .on: "On"
        case .off: "Off"
        case .toggle: "Toggle"
        }
    }
}
