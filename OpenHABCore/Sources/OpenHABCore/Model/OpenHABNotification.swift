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

public struct OpenHABNotification: Sendable {
    public var message: String?
    public var created: Date?
    public var icon: String?
    var severity: String?
    public var id = ""

    public init(message: String? = nil, created: Date? = nil, icon: String? = nil, severity: String? = nil, id: String = "") {
        self.message = message
        self.created = created
        self.icon = icon
        self.severity = severity
        self.id = id
    }
}

/// Decode an instance of OpenHABNotification.CodingData rather than decoding a OpenHABNotificaiton value directly,
/// then convert that into a openHABNotification
/// Inspired by https://www.swiftbysundell.com/basics/codable?rq=codingdata
public extension OpenHABNotification {
    struct CodingData: Decodable {
        private enum CodingKeys: String, CodingKey {
            case id = "_id"
            case message
            case v = "__v"
            case created
        }

        let id: String
        let message: String?
        let v: Int
        let created: Date?
    }
}

/// Convenience method to convert a decoded value into a proper OpenHABNotification instance
extension OpenHABNotification.CodingData {
    var openHABNotification: OpenHABNotification {
        OpenHABNotification(message: message, created: created, id: id)
    }
}
