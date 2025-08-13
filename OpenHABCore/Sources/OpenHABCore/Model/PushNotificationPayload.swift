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

public struct NotificationAction: Codable, Sendable {
    public let action: String
    public let title: String
}

public struct PushNotificationPayload: Sendable {
    public let message: String?
    public let title: String?
    public let action: String?
    public let cloudUserId: String?
    public let tag: String?
    public let referenceId: String?
    public let type: String?
    public let actions: [NotificationAction]?
    public let mediaAttachmentUrl: URL?
    public let category: String?

    public var displayMessage: String {
        message ?? NSLocalizedString("message_not_decoded", comment: "")
    }

    public var isHideNotification: Bool {
        type == "hideNotification"
    }

    public init(userInfo: [AnyHashable: Any]) {
        message = userInfo["message"] as? String
        title = userInfo["title"] as? String

        // Handle both actionIdentifier and on-click for backward compatibility
        action = (userInfo["actionIdentifier"] as? String) ?? (userInfo["on-click"] as? String)

        cloudUserId = userInfo["userId"] as? String
        tag = userInfo["tag"] as? String
        referenceId = userInfo["reference-id"] as? String
        type = userInfo["type"] as? String

        // Parse actions array from JSON string
        if let actionsJson = userInfo["actions"] as? String,
           let actionsData = actionsJson.data(using: .utf8) {
            actions = try? JSONDecoder().decode([NotificationAction].self, from: actionsData)
        } else {
            actions = nil
        }

        // Parse media attachment URL
        if let urlString = userInfo["media-attachment-url"] as? String {
            mediaAttachmentUrl = URL(string: urlString)
        } else {
            mediaAttachmentUrl = nil
        }

        // Extract category from aps
        if let aps = userInfo["aps"] as? [String: Any] {
            category = aps["category"] as? String
        } else {
            category = nil
        }
    }
}
