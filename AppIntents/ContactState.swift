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

@available(iOS 17.0, macOS 14.0, *)
enum ContactState: String, AppEnum {
    case open = "OPEN"
    case closed = "CLOSED"

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Contact State")

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .open: DisplayRepresentation(title: "Open", synonyms: ["Opened", "Triggered", "Active"]),
        .closed: DisplayRepresentation(title: "Closed", synonyms: ["Shut", "Inactive", "Reset"])
    ]
}

@available(iOS 17.0, macOS 14.0, *)
extension ContactState: CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .open: "Open"
        case .closed: "Closed"
        }
    }
}
