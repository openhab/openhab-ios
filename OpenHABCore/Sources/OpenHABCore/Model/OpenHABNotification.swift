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

/// An actionable button attached to a notification, shown in the in-app notification list
/// and toasts for interaction parity with the push notification's action buttons.
// TODO: Consider unifying with PushNotificationPayload.NotificationAction (same shape: title + action);
// they are kept separate for now because the list model and the APNs push payload decode from
// different sources.
public struct NotificationActionItem: Sendable, Decodable, Hashable {
    public let title: String
    public let action: String

    public init(title: String, action: String) {
        self.title = title
        self.action = action
    }
}

/// Rich, optionally-nested notification data from develop's #1226 (media attachments, reference id, …).
/// See the CodingData TODO below about where these fields live in the live cloud notification JSON.
public struct Payload: Hashable, Sendable {
    public let onClick: String?
    public let referenceId: String?
    public let icon: String?
    public let mediaAttachmentURL: URL?
    public let tag: String?
    public let type: String?
    public let message: String?
    public let title: String?
    public let userId: String?

    public init(onClick: String? = nil, referenceId: String? = nil, icon: String? = nil, mediaAttachmentURL: URL? = nil, tag: String? = nil, type: String? = nil, message: String? = nil, title: String? = nil, userId: String? = nil) {
        self.onClick = onClick
        self.referenceId = referenceId
        self.icon = icon
        self.mediaAttachmentURL = mediaAttachmentURL
        self.tag = tag
        self.type = type
        self.message = message
        self.title = title
        self.userId = userId
    }
}

public struct OpenHABNotification: Identifiable, Hashable, Sendable {
    // MARK: - Public properties (domain model)

    public let id: String
    public let message: String?
    public let icon: String?
    public let severity: String?
    /// Tap-to-navigate target. Read from the top-level `on-click` (cloud list API); falls back to
    /// `payload.onClick` when only the nested form is present.
    public let onClickAction: String?
    /// Action buttons offered by this notification (empty when none). Powers the in-app
    /// notification list and toast action buttons.
    public let actions: [NotificationActionItem]
    /// myopenHAB account user id (top-level `userId`), used to scope actions to the right home.
    public let cloudUserId: String?
    /// Rich extras (media attachment, reference id, tag, …); `nil` for plain flat notifications.
    public let payload: Payload?
    public let created: Date?
    public let v: Int

    /// A convenient view-facing display string: payload title → root message → payload message
    public var title: String {
        if let payloadTitle = payload?.title, !payloadTitle.isEmpty { return payloadTitle }
        if let msg = message, !msg.isEmpty { return msg }
        return payload?.message ?? ""
    }

    /// The message body shown beneath the title, only present when title comes from payload.title.
    public var subtitle: String? {
        guard let payloadTitle = payload?.title, !payloadTitle.isEmpty else { return nil }
        if let msg = message, !msg.isEmpty { return msg }
        if let payloadMsg = payload?.message, !payloadMsg.isEmpty { return payloadMsg }
        return nil
    }

    public init(id: String,
                message: String?,
                icon: String? = nil,
                severity: String? = nil,
                onClickAction: String? = nil,
                actions: [NotificationActionItem] = [],
                cloudUserId: String? = nil,
                payload: Payload? = nil,
                created: Date? = nil,
                v: Int) {
        self.id = id
        self.message = message
        self.icon = icon
        self.severity = severity
        self.onClickAction = onClickAction
        self.actions = actions
        self.cloudUserId = cloudUserId
        self.payload = payload
        self.created = created
        self.v = v
    }
}

/// Decode an instance of OpenHABNotification.CodingData rather than decoding a OpenHABNotificaiton value directly,
/// then convert that into a openHABNotification
/// Inspired by https://www.swiftbysundell.com/basics/codable?rq=codingdata
public extension OpenHABNotification {
    struct CodingData: Decodable {
        // TODO: DEVELOP MERGE — verify notification JSON shape against the live cloud API.
        // The cloud notification-LIST response (per OpenHABJSONParserTests fixtures, incl. legacy data)
        // is FLAT: `on-click`, `actions`, `userId` sit at the TOP level of each notification object.
        // develop's #1226 instead modelled a nested `payload` object (media-attachment-url, reference-id,
        // tag, type). Those two describe different sources — the flat REST list vs. the APNs push
        // userInfo (now handled by PushNotificationPayload). This decoder reads the flat top-level fields
        // (matching the shipped feature + tests) AND an optional nested `payload` (nil for flat
        // notifications). If the live list API actually nests media-attachment-url/reference-id, move
        // those reads accordingly. The server API is not believed to have changed in a breaking way.
        private enum CodingKeys: String, CodingKey {
            case id = "_id"
            case message
            case icon
            case severity
            case created
            case v = "__v"
            case onClickAction = "on-click"
            case actionsJSON = "actions"
            case cloudUserId = "userId"
            case payload
        }

        public struct PayloadInternal: Decodable {
            // swiftlint:disable nesting
            private enum CodingKeys: String, CodingKey {
                case onClick = "on-click"
                case referenceId = "reference-id"
                case icon
                case mediaAttachmentURL = "media-attachment-url"
                case tag
                case type
                case message
                case title
                case userId
            }

            // swiftlint:enable nesting

            public let onClick: String?
            public let referenceId: String?
            public let icon: String?
            public let mediaAttachmentURL: URL?
            public let tag: String?
            public let type: String?
            public let message: String?
            public let title: String?
            public let userId: String?
        }

        public let id: String
        public let message: String?
        public let icon: String?
        public let severity: String?
        public let created: Date?
        public let v: Int
        public let onClickAction: String?
        /// The notification-list API returns `actions` as a JSON string (array of {title, action}).
        public let actionsJSON: String?
        public let cloudUserId: String?
        public let payload: PayloadInternal?
    }
}

/// Convenience method to convert a decoded value into a proper OpenHABNotification instance
extension OpenHABNotification.CodingData {
    var openHABNotification: OpenHABNotification {
        OpenHABNotification(
            id: id,
            message: message,
            icon: icon,
            severity: severity,
            // Prefer the flat top-level on-click; fall back to a nested payload.onClick if that's all
            // the server sent.
            onClickAction: onClickAction ?? payload?.onClick,
            actions: parsedActions,
            cloudUserId: cloudUserId ?? payload?.userId,
            payload: payload.map {
                Payload(
                    onClick: $0.onClick,
                    referenceId: $0.referenceId,
                    icon: $0.icon,
                    mediaAttachmentURL: $0.mediaAttachmentURL,
                    tag: $0.tag,
                    type: $0.type,
                    message: $0.message,
                    title: $0.title,
                    userId: $0.userId
                )
            },
            created: created,
            v: v
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
