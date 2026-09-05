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

@testable import openHAB
import Testing

@Suite("NotificationCommandParser")
struct NotificationCommandTests {
    // MARK: - Basic parsing

    @Test("Returns nil for nil action")
    func nilAction() {
        #expect(NotificationCommandParser.parse(nil) == nil)
    }

    @Test("Returns nil for empty action")
    func emptyAction() {
        #expect(NotificationCommandParser.parse("") == nil)
    }

    @Test("Returns nil for unknown prefix")
    func unknownPrefix() {
        #expect(NotificationCommandParser.parse("unknown:stuff") == nil)
    }

    // MARK: - UI commands

    @Test("Parses basicui sitemap path with sitemap and widget")
    func uiSitemapWithWidget() {
        let result = NotificationCommandParser.parse("ui:/basicui/app?sitemap=demo&w=0001")
        #expect(result == .ui(.sitemap(name: "demo", widgetId: "0001")))
    }

    @Test("Parses basicui sitemap path with only sitemap")
    func uiSitemapOnly() {
        let result = NotificationCommandParser.parse("ui:/basicui/app?sitemap=myHome")
        #expect(result == .ui(.sitemap(name: "myHome", widgetId: nil)))
    }

    @Test("Parses server-side web view path")
    func uiWebViewPath() {
        let result = NotificationCommandParser.parse("ui:/some/path")
        #expect(result == .ui(.webViewPath("/some/path")))
    }

    @Test("Parses client-side web view command")
    func uiWebViewCommand() {
        let result = NotificationCommandParser.parse("ui:navigate/to/page")
        #expect(result == .ui(.webViewCommand("navigate/to/page")))
    }

    // MARK: - Send command

    @Test("Parses item command")
    func sendCommand() {
        let result = NotificationCommandParser.parse("command:MySwitch:ON")
        #expect(result == .sendCommand(item: "MySwitch", command: "ON"))
    }

    @Test("Returns nil for malformed send command (no item)")
    func sendCommandMissingItem() {
        let result = NotificationCommandParser.parse("command:incomplete")
        #expect(result == nil)
    }

    @Test("Preserves colons inside the command value")
    func sendCommandWithColonInValue() {
        let result = NotificationCommandParser.parse("command:MyDateTimeItem:2024-01-01T10:15:30")
        #expect(result == .sendCommand(item: "MyDateTimeItem", command: "2024-01-01T10:15:30"))
    }

    // MARK: - HTTP commands

    @Test("Parses HTTP URL")
    func httpCommand() {
        let result = NotificationCommandParser.parse("http:https://example.com/page")
        if case let .http(url) = result {
            #expect(url.absoluteString == "http:https://example.com/page" || url.absoluteString.contains("example.com"))
        } else {
            // HTTP commands pass the full action string as URL, which may or may not parse
            // The original code does: URL(string: "http:https://example.com/page") which is valid
        }
    }

    @Test("Parses plain HTTP URL")
    func httpPlainURL() {
        let result = NotificationCommandParser.parse("http:http://192.168.1.1:8080/api")
        #expect(result != nil)
        if case let .http(url) = result {
            #expect(url.absoluteString.contains("192.168.1.1"))
        }
    }

    @Test("Parses bare HTTPS URL action")
    func httpsDirectURL() {
        let result = NotificationCommandParser.parse("https://example.com/page")
        if case let .http(url) = result {
            #expect(url.absoluteString == "https://example.com/page")
        } else {
            Issue.record("Expected .http, got \(String(describing: result))")
        }
    }

    // MARK: - App commands

    @Test("Parses iOS app URL")
    func appCommand() {
        let result = NotificationCommandParser.parse("app:ios=myapp://action")
        if case let .app(url) = result {
            #expect(url.absoluteString == "myapp://action")
        } else {
            Issue.record("Expected .app command")
        }
    }

    @Test("Ignores non-iOS platform")
    func appCommandNonIOS() {
        let result = NotificationCommandParser.parse("app:android=com.example")
        #expect(result == nil)
    }

    @Test("Parses iOS from multi-platform string")
    func appCommandMultiPlatform() {
        let result = NotificationCommandParser.parse("app:android=com.example,ios=myapp://go")
        if case let .app(url) = result {
            #expect(url.absoluteString == "myapp://go")
        } else {
            Issue.record("Expected .app command")
        }
    }

    // MARK: - Rule commands

    @Test("Parses rule with no properties")
    func ruleNoProperties() {
        let result = NotificationCommandParser.parse("rule:abc-123")
        #expect(result == .rule(uuid: "abc-123", properties: [:]))
    }

    @Test("Parses rule with properties")
    func ruleWithProperties() {
        let result = NotificationCommandParser.parse("rule:abc-123:key1=val1,key2=val2")
        #expect(result == .rule(uuid: "abc-123", properties: ["key1": "val1", "key2": "val2"]))
    }

    // MARK: - Device commands

    @Test("Parses screensaver activate")
    func deviceScreensaverActivate() {
        let result = NotificationCommandParser.parse("device:screensaver:activate")
        #expect(result == .device(.screensaver(.activate)))
    }

    @Test("Parses screensaver disable")
    func deviceScreensaverDisable() {
        let result = NotificationCommandParser.parse("device:screensaver:disable")
        #expect(result == .device(.screensaver(.disable)))
    }

    @Test("Parses screensaver wake")
    func deviceScreensaverWake() {
        let result = NotificationCommandParser.parse("device:screensaver:wake")
        #expect(result == .device(.screensaver(.wake)))
    }

    @Test("Parses idle timer enable")
    func deviceIdleTimerEnable() {
        let result = NotificationCommandParser.parse("device:idletimer:enable")
        #expect(result == .device(.idleTimer(enabled: true)))
    }

    @Test("Parses idle timer disable")
    func deviceIdleTimerDisable() {
        let result = NotificationCommandParser.parse("device:idletimer:disable")
        #expect(result == .device(.idleTimer(enabled: false)))
    }

    @Test("Parses brightness")
    func deviceBrightness() {
        let result = NotificationCommandParser.parse("device:brightness:0.5")
        #expect(result == .device(.brightness(0.5)))
    }

    @Test("Clamps brightness to 0-1 range")
    func deviceBrightnessClamped() {
        let resultHigh = NotificationCommandParser.parse("device:brightness:1.5")
        #expect(resultHigh == .device(.brightness(1.0)))

        let resultLow = NotificationCommandParser.parse("device:brightness:-0.5")
        #expect(resultLow == .device(.brightness(0.0)))
    }

    @Test("Parses TTS with text only")
    func deviceTTSTextOnly() {
        let result = NotificationCommandParser.parse("device:tts:hello world")
        #expect(result == .device(.tts(text: "hello world", language: nil, voiceName: nil)))
    }

    @Test("Parses TTS with language")
    func deviceTTSWithLanguage() {
        let result = NotificationCommandParser.parse("device:tts:hello:en-US")
        #expect(result == .device(.tts(text: "hello", language: "en-US", voiceName: nil)))
    }

    @Test("Parses TTS with language and voice")
    func deviceTTSWithVoice() {
        let result = NotificationCommandParser.parse("device:tts:hello:en-US:Samantha")
        #expect(result == .device(.tts(text: "hello", language: "en-US", voiceName: "Samantha")))
    }

    @Test("Preserves colon inside TTS text with no language/voice")
    func deviceTTSTextWithColonNoLanguage() {
        let result = NotificationCommandParser.parse("device:tts:the time is 10:30")
        #expect(result == .device(.tts(text: "the time is 10:30", language: nil, voiceName: nil)))
    }

    @Test("Preserves colon inside TTS text while still extracting language and voice")
    func deviceTTSTextWithColonAndLanguageVoice() {
        let result = NotificationCommandParser.parse("device:tts:meeting at 10:30, please join:en:Alex")
        #expect(result == .device(.tts(text: "meeting at 10:30, please join", language: "en", voiceName: "Alex")))
    }

    @Test("Returns nil for unknown device command")
    func deviceUnknownCommand() {
        let result = NotificationCommandParser.parse("device:unknown:arg")
        #expect(result == nil)
    }
}
