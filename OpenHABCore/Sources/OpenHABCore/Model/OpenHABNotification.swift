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

public struct OpenHABNotification: Identifiable, Hashable, Sendable {
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
    }

    // MARK: - Public properties (domain model)

    public let id: String
    public let message: String?
    public let icon: String?
    public let severity: String?
    public let payload: Payload?
    public let created: Date?
    public let v: Int

    // A convenient view-facing title (falls back to message)
    public var title: String {
        payload?.title?.isEmpty == false ? payload!.title! : (message ?? "")
    }

    // Prefer root message, fall back to payload.message
    public init(id: String,
                message: String?,
                icon: String? = nil,
                severity: String? = nil,
                payload: Payload? = nil,
                created: Date? = nil,
                v: Int) {
        self.id = id
        self.message = message
        self.icon = icon
        self.severity = severity
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
        private enum CodingKeys: String, CodingKey {
            case id = "_id"
            case message
            case icon
            case severity
            case payload
            case created
            case v = "__v"
        }

        public struct Payload: Decodable {
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
        public let payload: Payload?
        public let created: Date?
        public let v: Int
    }
}

/// Convenience method to convert a decoded value into a proper OpenHABNotification instance
extension OpenHABNotification.CodingData {
    var openHABNotification: OpenHABNotification {
        print("Passing through convenience")
        return OpenHABNotification(
            id: id,
            message: message,
            icon: icon,
            severity: severity,
            payload: payload.map {
                OpenHABNotification.Payload(
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
            created: created ?? Date(),
            v: v
        )
    }
}
