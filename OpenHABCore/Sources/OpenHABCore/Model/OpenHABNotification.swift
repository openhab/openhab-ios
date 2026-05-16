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

public struct NotificationActionItem: Sendable, Decodable, Equatable {
    public let title: String
    public let action: String

    public init(title: String, action: String) {
        self.title = title
        self.action = action
    }
}

public struct OpenHABNotification: Sendable {
    public var message: String?
    public var created: Date?
    public var icon: String?
    var severity: String?
    public var id = ""
    public var onClickAction: String?
    public var actions: [NotificationActionItem]
    public var cloudUserId: String?

    public init(
        message: String? = nil,
        created: Date? = nil,
        icon: String? = nil,
        severity: String? = nil,
        id: String = "",
        onClickAction: String? = nil,
        actions: [NotificationActionItem] = [],
        cloudUserId: String? = nil
    ) {
        self.message = message
        self.created = created
        self.icon = icon
        self.severity = severity
        self.id = id
        self.onClickAction = onClickAction
        self.actions = actions
        self.cloudUserId = cloudUserId
    }
}

// Decode an instance of OpenHABNotification.CodingData rather than decoding a OpenHABNotificaiton value directly,
// then convert that into a openHABNotification
// Inspired by https://www.swiftbysundell.com/basics/codable?rq=codingdata
public extension OpenHABNotification {
    struct CodingData: Decodable {
        private enum CodingKeys: String, CodingKey {
            case id = "_id"
            case message
            case v = "__v"
            case created
            case onClickAction = "on-click"
            case actionsJSON = "actions"
            case cloudUserId = "userId"
        }

        let id: String
        let message: String?
        let v: Int
        let created: Date?
        let onClickAction: String?
        let actionsJSON: String?
        let cloudUserId: String?
    }
}

// Convenience method to convert a decoded value into a proper OpenHABNotification instance
extension OpenHABNotification.CodingData {
    var openHABNotification: OpenHABNotification {
        OpenHABNotification(
            message: message,
            created: created,
            id: id,
            onClickAction: onClickAction,
            actions: parsedActions,
            cloudUserId: cloudUserId
        )
    }

    private var parsedActions: [NotificationActionItem] {
        guard let json = actionsJSON,
              let data = json.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: String]]
        else { return [] }
        return raw.compactMap { dict in
            guard let title = dict["title"], let action = dict["action"] else { return nil }
            return NotificationActionItem(title: title, action: action)
        }
    }
}
