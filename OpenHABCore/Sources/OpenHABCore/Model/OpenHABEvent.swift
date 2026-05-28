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

public struct OpenHABEvent: Decodable, Hashable, Sendable {
    enum EventType: String, Decodable {
        case itemStateEvent = "ItemStateEvent"
        case itemStateUpdatedEvent = "ItemStateUpdatedEvent"
        case itemStateChangedEvent = "ItemStateChangedEvent"
    }

    struct Payload: Decodable, Equatable, Hashable {
        private enum CodingKeys: String, CodingKey {
            case type, value, oldType, oldValue, lastStateUpdate, lastStateChange
        }

        let type: String
        let value: String

        // Optional for updated/changed events
        let oldType: String?
        let oldValue: String?
        let lastStateUpdate: Date?
        let lastStateChange: Date?
    }

    let topic: String
    let payload: Payload
    let type: EventType
}
