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

import AVFoundation
import OpenHABCore
import os.log
import SafariServices
import SwiftUI
@preconcurrency import UserNotifications

enum NavigationCommand: Equatable {
    case switchToWebView(path: String?)
    case switchToSitemap(name: String, widgetId: String?)
}

@MainActor
class NotificationActionService: ObservableObject {
    // MARK: - Published state

    @Published var navigationCommand: NavigationCommand?

    // MARK: - Retry configuration

    /// Maximum number of automatic retries after a transient network failure.
    var maxRetryCount = 3
    /// Base interval (seconds) for exponential back-off: attempt n waits `retryBackoffBase × 2ⁿ`.
    var retryBackoffBase: TimeInterval = 2.0

    // MARK: - Injectable network back-ends (swap in tests)

    /// Sends an item command to the openHAB server.
    var commandSender: (String, String, String?) async throws -> Void = { item, command, deviceId in
        try await NetworkTracker.shared.send(to: item, command: command, deviceId: deviceId)
    }

    /// Triggers an openHAB rule by UID.
    var ruleSender: (String, [String: String]) async throws -> Void = { ruleUID, payload in
        try await NetworkTracker.shared.runNow(ruleUID: ruleUID, payload: payload)
    }

    // MARK: - Private state

    private var synthesizer = AVSpeechSynthesizer()
    private var streamTask: Task<Void, Never>?

    init(autoStart: Bool = true) {
        if autoStart {
            startSSEListening()
            setupNotificationHandling()
        }
    }

    // MARK: - SSE

    private func startSSEListening() {
        Task {
            await ItemEventStream.startMonitoringNetwork()
        }
        Logger.viewController.debug("Starting SSE")
        streamTask = Task { [weak self] in
            guard let self else { return }
            for await msg in await ItemEventStream.shared.stream() {
                await MainActor.run { self.handleSSEMessage(msg) }
            }
        }
    }

    private func handleSSEMessage(_ msg: StreamOutput<StateStreamMessage>) {
        switch msg {
        case .connected:
            Logger.viewController.debug("SSE Connected")
        case let .disconnected(err):
            Logger.viewController.debug("SSE Disconnected: \(err?.localizedDescription ?? "nil")")
        case let .event(sm):
            switch sm {
            case let .state(item, state):
                Logger.viewController.debug("SSE Item \(item): \(state)")
                handleNotificationInternal(state)
            case let .ready(uuid, _):
                Logger.viewController.debug("SSE Session UUID: \(uuid)")
            case let .unknown(raw):
                Logger.viewController.debug("SSE Unknown: \(raw)")
            default:
                break
            }
        }
    }

    // MARK: - Notification Handling

    private func setupNotificationHandling() {
        NotificationCenter.default.addObserver(
            forName: .openHABHandleNotificationAction,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            let action = notification.userInfo?["action"] as? String
            let cloudUserId = notification.userInfo?["cloudUserId"] as? String
            Task { @MainActor in
                self?.handleNotification(action: action, cloudUserId: cloudUserId)
            }
        }
    }

    func handleNotification(action: String?, cloudUserId: String?) {
        guard let action else { return }

        Logger.viewController.info("handleNotification cloudUserId: \(cloudUserId ?? "<none>")")

        Task {
            if let cloudUserId,
               let targetHome = await Preferences.shared.storedHome(forCloudUserId: cloudUserId),
               (await Preferences.shared.currentHomePreferences).remoteConnectionConfig.cloudUserId != cloudUserId {
                await NetworkTracker.shared.stopTracking()
                Logger.viewController.info("Switching to home \(targetHome.id)")
                await Preferences.shared.switchActiveHome(to: targetHome.id)
            }
            let homePrefs = await Preferences.shared.currentHomePreferences
            await NetworkTracker.shared.startTracking(
                connectionConfigurations: homePrefs.trackedConnections
            )
            _ = await NetworkTracker.shared.waitForActiveConnection()
            handleNotificationInternal(action)
        }
    }

    func handleNotificationInternal(_ action: String?) {
        guard let parsed = NotificationCommandParser.parse(action) else { return }

        switch parsed {
        case let .ui(target):
            handleUICommand(target)
        case let .sendCommand(item, command):
            sendItemCommand(item: item, command: command)
        case let .http(url):
            openInSafari(url: url)
        case let .app(url):
            Logger.viewController.info("appCommandAction opening \(url.absoluteString)")
            UIApplication.shared.open(url)
        case let .rule(uuid, properties):
            executeRule(uuid: uuid, properties: properties)
        case let .device(deviceCmd):
            handleDeviceCommand(deviceCmd)
        }
    }

    private func handleUICommand(_ target: NotificationCommand.UITarget) {
        switch target {
        case let .sitemap(name, widgetId):
            navigationCommand = .switchToSitemap(name: name, widgetId: widgetId)
        case let .webViewPath(path):
            navigationCommand = .switchToWebView(path: path)
        case let .webViewCommand(command):
            navigationCommand = .switchToWebView(path: command)
        }
    }

    private func sendItemCommand(item: String, command: String) {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString
        Task {
            do {
                try await withRetry {
                    Logger.viewController.info("Sending command")
                    try await self.commandSender(item, command, deviceId)
                }
            } catch NetworkTrackerError.noActiveConnection {
                displayErrorNotification("Could not find server")
            } catch {
                displayErrorNotification("Failed to establish a connection: \(error.localizedDescription)")
                Logger.viewController.error("Could not send data \(error.localizedDescription)")
            }
        }
    }

    private func displayErrorNotification(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Could not send command"
        content.body = message
        content.sound = UNNotificationSound.default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func openInSafari(url: URL) {
        let vc = SFSafariViewController(url: url)
        UIApplication.shared.firstKeyWindow?.rootViewController?.present(vc, animated: true)
    }

    private func executeRule(uuid: String, properties: [String: String]) {
        Task {
            do {
                try await withRetry {
                    Logger.viewController.info("Executing rule \(uuid)")
                    try await self.ruleSender(uuid, properties)
                    Logger.viewController.info("Request succeeded")
                }
            } catch let error as NetworkTrackerError {
                displayErrorNotification("\(error.localizedDescription)")
            } catch {
                Logger.viewController.error("Could not send data \(error.localizedDescription)")
                displayErrorNotification("Request to server failed: \(error.localizedDescription)")
            }
        }
    }

    /// Runs `operation` up to `maxRetryCount + 1` times with exponential back-off.
    /// Cancellation propagates immediately; all other errors trigger a retry delay.
    /// Throws the last error when all attempts are exhausted.
    func withRetry(operation: () async throws -> Void) async throws {
        let retries = maxRetryCount
        let backoff = retryBackoffBase
        for attempt in 0...retries {
            do {
                try await operation()
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                guard attempt < retries else { throw error }
                let delay = backoff * pow(2.0, Double(attempt))
                Logger.viewController.info("Operation failed (attempt \(attempt + 1)/\(retries + 1)), retrying in \(delay, format: .fixed(precision: 1))s: \(error.localizedDescription)")
                try await Task.sleep(for: .seconds(delay))
            }
        }
    }

    private func handleDeviceCommand(_ cmd: NotificationCommand.DeviceCommand) {
        switch cmd {
        case let .screensaver(action):
            switch action {
            case .activate: NotificationCenter.default.post(name: .activateScreenSaver, object: nil)
            case .disable: NotificationCenter.default.post(name: .disableScreenSaver, object: nil)
            case .wake: NotificationCenter.default.post(name: .wakeScreenSaver, object: nil)
            }
        case let .idleTimer(enabled):
            IdleTimerService.shared.isDisabled = !enabled
        case let .brightness(value):
            UIApplication.shared.firstKeyWindow?.windowScene?.screen.brightness = value
        case let .tts(text, language, voiceName):
            guard !text.isEmpty else {
                Logger.viewController.debug("TTS command received empty text — ignoring")
                return
            }
            Logger.viewController.debug("Attempting to speak text \(text, privacy: .private)")
            let utterance = AVSpeechUtterance(string: text)
            if let language, let voiceName {
                func normalizeVoiceName(from input: String) -> String {
                    input.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
                }
                let voice = AVSpeechSynthesisVoice.speechVoices().filter {
                    $0.language.lowercased() == language.lowercased() && normalizeVoiceName(from: $0.name) == normalizeVoiceName(from: voiceName)
                }
                if !voice.isEmpty {
                    utterance.voice = voice[0]
                }
            } else if let language {
                utterance.voice = AVSpeechSynthesisVoice(language: language)
            }
            // Reset synthesizer to recover from audio interruptions
            // (e.g. WebRTC audio in a WKWebView stealing the session).
            // Use .mixWithOthers so TTS coexists with WebRTC instead of
            // fighting for exclusive audio session control.
            synthesizer.stopSpeaking(at: .immediate)
            synthesizer = AVSpeechSynthesizer()
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(audioSession.category, mode: audioSession.mode, options: audioSession.categoryOptions.union(.mixWithOthers))
                try audioSession.setActive(true)
            } catch {
                Logger.viewController.warning("Failed to configure audio session for TTS: \(error.localizedDescription)")
            }
            synthesizer.speak(utterance)
        }
    }
}

// MARK: - Notification name for routing

extension Notification.Name {
    static let openHABHandleNotificationAction = Notification.Name("openHABHandleNotificationAction")
}
