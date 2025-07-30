// Copyright (c) 2010-2025 Contributors to the openHAB project
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

    struct Payload: Decodable, Equatable, Hashable, Sendable {
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

        // Custom decoder to parse ISO8601 with zone offset and region
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try container.decode(String.self, forKey: .type)
            value = try container.decode(String.self, forKey: .value)
            oldType = try container.decodeIfPresent(String.self, forKey: .oldType)
            oldValue = try container.decodeIfPresent(String.self, forKey: .oldValue)

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone, .withColonSeparatorInTimeZone]

            func parseDate(_ key: CodingKeys) -> Date? {
                guard let raw = try? container.decode(String.self, forKey: key) else { return nil }
                let trimmed = raw.components(separatedBy: "[").first ?? raw
                return formatter.date(from: trimmed)
            }

            lastStateUpdate = parseDate(.lastStateUpdate)
            lastStateChange = parseDate(.lastStateChange)
        }
    }

    let topic: String
    let payload: Payload
    let type: EventType
}
