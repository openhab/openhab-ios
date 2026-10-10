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

// Swift side of the host bridge protocol. The schema is docs/mainui-bridge/protocol.d.ts.

// MARK: - Envelope

struct OHBridgeHeader: Decodable {
    let type: String
    let id: String?
    let replyTo: String?
}

struct OHBridgeIncoming<Payload: Decodable>: Decodable {
    let payload: Payload
}

struct OHBridgeOutgoing<Payload: Encodable>: Encodable {
    let v = OHBridge.protocolVersion
    let type: String
    let id: String?
    let replyTo: String?
    let payload: Payload
}

struct OHBridgeEmpty: Codable {}

struct OHBridgeReplyError: Codable, Equatable {
    static let notReady = "not_ready"

    let code: String
    let message: String?
}

/// Only the parts of a reply the host acts on. `result` is left to the request that asked.
struct OHBridgeReply: Decodable {
    let ok: Bool
    let error: OHBridgeReplyError?
}

struct OHBridgeCredentialsReply: Encodable {
    private enum CodingKeys: String, CodingKey {
        case ok, result
    }

    let ok = true
    let result: OHBridgeCredentials?

    /// Encode a missing result as an explicit null, so the page can tell "none" from "no answer".
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ok, forKey: .ok)
        try container.encode(result, forKey: .result)
    }
}

struct OHBridgeCredentials: Encodable {
    let username: String
    let password: String
}

// MARK: - Startup data

struct OHBridgeHostInfo: Encodable {
    let `protocol` = OHBridge.protocolVersion
    let platform = "ios"
    let appVersion: String
    let features: [String]
    let initialHistory: [String]?
    let initialProps: [OHBridgeProps]?
    let layout: OHBridgeLayout
}

/// What a page was opened with. The app never looks inside, it only keeps it and hands it back,
/// so it holds it as JSON text, the way it is saved, and sends it as the object it is.
struct OHBridgeProps: Codable, Equatable {
    private enum JSONValue: Codable {
        case null
        case bool(Bool)
        case number(Double)
        case string(String)
        case array([JSONValue])
        case object([String: JSONValue])

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                self = .null
            } else if let bool = try? container.decode(Bool.self) {
                self = .bool(bool)
            } else if let number = try? container.decode(Double.self) {
                self = .number(number)
            } else if let string = try? container.decode(String.self) {
                self = .string(string)
            } else if let array = try? container.decode([JSONValue].self) {
                self = .array(array)
            } else {
                self = try .object(container.decode([String: JSONValue].self))
            }
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .null: try container.encodeNil()
            case let .bool(bool): try container.encode(bool)
            case let .number(number): try container.encode(number)
            case let .string(string): try container.encode(string)
            case let .array(array): try container.encode(array)
            case let .object(object): try container.encode(object)
            }
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    let json: String

    init(json: String) {
        self.json = json
    }

    init(from decoder: any Decoder) throws {
        let value = try JSONValue(from: decoder)
        guard case .object = value else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "props must be an object"))
        }
        json = try String(bytes: Self.encoder.encode(value), encoding: .utf8) ?? WebRouteRestore.noProps
    }

    /// Text that isn't a JSON object goes out as an empty one, which is what a page opened with
    /// nothing passed to it gets.
    func encode(to encoder: any Encoder) throws {
        let value = try? JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        guard let value, case .object = value else {
            try JSONValue.object([:]).encode(to: encoder)
            return
        }
        try value.encode(to: encoder)
    }
}

struct OHBridgeLayout: Codable, Equatable {
    struct Insets: Codable, Equatable {
        let top: Double
        let bottom: Double
    }

    let insets: Insets
    let navbarHeight: Double?
}

// MARK: - Web → host

struct OHBridgeHello: Decodable, Equatable {
    enum Impl: String, Decodable {
        case mainui, shim, other
    }

    let impl: Impl
    let version: String?
    let accepted: [String]
    let features: [String]
}

struct OHBridgeConnectionState: Decodable {
    let sseConnected: Bool
}

struct OHBridgeNavState: Codable, Equatable {
    let path: String
    let history: [String]
    let props: [OHBridgeProps]?
    let modal: Bool
}

struct OHBridgeNavbarState: Decodable, Equatable {
    struct Back: Decodable, Equatable {
        let label: String?
    }

    static let empty = OHBridgeNavbarState(title: "", titleInContent: false, hidden: false, back: nil, leading: [], trailing: [])

    let title: String
    let titleInContent: Bool
    let hidden: Bool
    let back: Back?
    let leading: [OHBridgeNavbarAction]
    let trailing: [OHBridgeNavbarAction]

    /// Every button except back, in reading order.
    var actions: [OHBridgeNavbarAction] {
        leading + trailing
    }
}

struct OHBridgeNavbarAction: Decodable, Equatable, Identifiable {
    let id: String
    /// Empty for a button that only shows an icon.
    let label: String
    let icon: OHBridgeIcon?
    let disabled: Bool?

    /// What VoiceOver reads and UI tests find the button by: the label, or for an icon-only
    /// button its icon's name, e.g. "square list" for `f7:square_list`.
    var accessibilityName: String {
        guard label.isEmpty, let name = icon?.name else { return label }
        let glyph = name.split(separator: ":").last.map(String.init) ?? name
        return glyph.replacing("_", with: " ")
    }
}

struct OHBridgeMenuState: Decodable, Equatable {
    let sections: [OHBridgeMenuSection]
}

struct OHBridgeMenuSection: Decodable, Equatable, Identifiable {
    let id: String
    let title: String?
    let items: [OHBridgeMenuItem]
}

struct OHBridgeMenuItem: Decodable, Equatable, Identifiable {
    let id: String
    let label: String
    let footer: String?
    let icon: OHBridgeIcon?
    let path: String?
    let active: Bool?
    let children: [OHBridgeMenuItem]?
    let more: [OHBridgeMenuItem]?
}

/// Main UI's own icon strings: `f7:name`, `material:name`, `oh:set:name`, `iconify:set:name`, or
/// a bare openHAB icon name. `svg` only when there is no name to send.
struct OHBridgeIcon: Decodable, Equatable {
    let name: String?
    let md: String?
    let svg: String?
}

// MARK: - Host → web

struct OHBridgeNavigate: Encodable {
    let path: String
}

struct OHBridgeOpenModal: Encodable {
    let kind: OHBridgeModalKind
    let target: String
}

enum OHBridgeModalKind: String, Encodable {
    case popup, popover, sheet
}

/// A Main UI router command in its old `handleCommand` string form, as server-sent `ui:`
/// notification actions carry them: "navigate:/page/x", "popup:widget:y", "close", "back",
/// "reload".
enum OHBridgeCommand: Equatable {
    case navigate(String)
    case openModal(OHBridgeModalKind, target: String)
    case closeModals
    case back
    case reload

    /// Nil for anything with no bridge message, e.g. "notification:…", which the app shows itself.
    init?(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        let verb = trimmed.split(separator: ":", maxSplits: 1).first.map(String.init) ?? trimmed
        let target = trimmed.count > verb.count ? String(trimmed.dropFirst(verb.count + 1)) : ""
        switch verb {
        case "navigate" where !target.isEmpty: self = .navigate(target)
        case "close": self = .closeModals
        case "back": self = .back
        case "reload": self = .reload
        default:
            guard let kind = OHBridgeModalKind(rawValue: verb), !target.isEmpty else { return nil }
            self = .openModal(kind, target: target)
        }
    }
}

struct OHBridgeActivate: Encodable {
    let id: String
}

// MARK: - Namespace

enum OHBridge {
    static let protocolVersion = 1
    /// Name of the WKScriptMessageHandler the page posts to.
    static let messageHandlerName = "OHBridge"

    /// Whether `url` is served from the origin described by `scheme`, `host` and `port`, as
    /// WebKit reports it (port 0 for the scheme's default).
    static func isSameOrigin(_ url: URL, scheme: String, host: String, port: Int) -> Bool {
        guard let urlScheme = url.scheme?.lowercased(), let urlHost = url.host?.lowercased() else { return false }
        let defaultPort = switch urlScheme {
        case "https": 443
        case "http": 80
        default: 0
        }
        return urlScheme == scheme.lowercased()
            && urlHost == host.lowercased()
            && (url.port ?? defaultPort) == (port == 0 ? defaultPort : port)
    }
}
