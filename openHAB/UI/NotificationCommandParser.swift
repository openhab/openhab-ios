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

/// Parsed representation of a notification action string.
/// The action format is `type:payload` where type determines routing.
enum NotificationCommand: Equatable {
    /// UI navigation command. The path may be a basicui sitemap path or a webview path.
    case ui(UITarget)
    /// Send a command to an openHAB item.
    case sendCommand(item: String, command: String)
    /// Open a URL in an external browser.
    case http(url: URL)
    /// Open a platform-specific app URL.
    case app(url: URL)
    /// Execute an openHAB rule by UUID, with optional properties.
    case rule(uuid: String, properties: [String: String])
    /// Device control command (screensaver, idle timer, brightness, TTS).
    case device(DeviceCommand)

    enum UITarget: Equatable {
        /// Navigate to a sitemap, optionally to a specific widget.
        case sitemap(name: String, widgetId: String?)
        /// Navigate to the web view with a server-side path (starts with /).
        case webViewPath(String)
        /// Navigate to the web view with a client-side command (handled by MainUI JS).
        case webViewCommand(String)
    }

    enum DeviceCommand: Equatable {
        case screensaver(ScreensaverAction)
        case idleTimer(enabled: Bool)
        case brightness(Double)
        case tts(text: String, language: String?, voiceName: String?)

        enum ScreensaverAction: String, Equatable {
            case activate, disable, wake
        }
    }
}

/// Parses notification action strings into structured `NotificationCommand` values.
enum NotificationCommandParser {
    /// Parse an action string like `"ui:/basicui/app?sitemap=demo&w=0001"` into a `NotificationCommand`.
    /// Returns `nil` if the action is nil, empty, or has an unrecognized prefix.
    static func parse(_ action: String?) -> NotificationCommand? {
        guard let action, !action.isEmpty else { return nil }
        let actionParts = action.split(separator: ":")
        guard !actionParts.isEmpty else { return nil }
        let cmd = actionParts.dropFirst().joined(separator: ":")

        switch actionParts[0] {
        case "ui":
            return parseUICommand(cmd)
        case "command":
            return parseSendCommand(cmd)
        case "http":
            // http commands pass the full original action (including "http:" prefix) as the URL
            return parseHTTPCommand(action)
        case "app":
            return parseAppCommand(cmd)
        case "rule":
            return parseRuleCommand(cmd)
        case "device":
            return parseDeviceCommand(cmd)
        default:
            return nil
        }
    }

    // MARK: - UI Command

    static func parseUICommand(_ command: String, defaultSitemap: String = "") -> NotificationCommand? {
        // The original regex /^(\/basicui\/app\?.*|\/.*|.*)$/ always matches
        // (the .* alternative accepts anything), so we just use the command directly.
        let path = command

        if path.starts(with: "/basicui/app?") {
            guard let urlComponents = URLComponents(string: path) else {
                return .ui(.sitemap(name: defaultSitemap, widgetId: nil))
            }
            let queryItems = urlComponents.queryItems
            let sitemap = queryItems?.first { $0.name == "sitemap" }?.value ?? defaultSitemap
            let widgetId = queryItems?.first { $0.name == "w" }?.value
            return .ui(.sitemap(name: sitemap, widgetId: widgetId))
        } else if path.starts(with: "/") {
            return .ui(.webViewPath(path))
        } else {
            return .ui(.webViewCommand(path))
        }
    }

    // MARK: - Send Command

    static func parseSendCommand(_ action: String) -> NotificationCommand? {
        let components = action.split(separator: ":")
        guard components.count == 2 else { return nil }
        return .sendCommand(item: String(components[0]), command: String(components[1]))
    }

    // MARK: - HTTP

    static func parseHTTPCommand(_ fullAction: String) -> NotificationCommand? {
        guard let url = URL(string: fullAction) else { return nil }
        return .http(url: url)
    }

    // MARK: - App

    static func parseAppCommand(_ command: String) -> NotificationCommand? {
        let pairs = command.split(separator: ",")
        for pair in pairs {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            if keyValue.count == 2, keyValue[0] == "ios" {
                if let url = URL(string: String(keyValue[1])) {
                    return .app(url: url)
                }
            }
        }
        return nil
    }

    // MARK: - Rule

    static func parseRuleCommand(_ command: String) -> NotificationCommand? {
        let components = command.split(separator: ":", maxSplits: 2)
        guard !components.isEmpty else { return nil }

        let uuid = String(components[0])
        var properties: [String: String] = [:]

        if components.count > 1 {
            let propertiesString = String(components[1])
            let propertyPairs = propertiesString.split(separator: ",")
            for pair in propertyPairs {
                let keyValue = pair.split(separator: "=", maxSplits: 1)
                if keyValue.count == 2 {
                    properties[String(keyValue[0])] = String(keyValue[1])
                }
            }
        }

        return .rule(uuid: uuid, properties: properties)
    }

    // MARK: - Device

    static func parseDeviceCommand(_ action: String) -> NotificationCommand? {
        let cmdParts = action.split(separator: ":")
        guard !cmdParts.isEmpty else { return nil }
        let command = cmdParts[0].lowercased()
        let arg1 = cmdParts.count > 1 ? String(cmdParts[1]).lowercased() : ""

        switch command {
        case "screensaver":
            guard let ssAction = NotificationCommand.DeviceCommand.ScreensaverAction(rawValue: arg1) else { return nil }
            return .device(.screensaver(ssAction))
        case "idletimer":
            switch arg1 {
            case "enable": return .device(.idleTimer(enabled: true))
            case "disable": return .device(.idleTimer(enabled: false))
            default: return nil
            }
        case "brightness":
            guard let value = Double(arg1) else { return nil }
            let clamped = min(max(value, 0.0), 1.0)
            return .device(.brightness(clamped))
        case "tts":
            let language: String? = cmdParts.count > 2 ? String(cmdParts[2]) : nil
            let voiceName: String? = cmdParts.count > 3 ? String(cmdParts[3]) : nil
            return .device(.tts(text: arg1, language: language, voiceName: voiceName))
        default:
            return nil
        }
    }
}
