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
import Combine
import FirebaseCrashlytics
import Kingfisher
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
class AppServicesViewModel: ObservableObject {
    // MARK: - Published state

    @Published var certificateAlert: CertificateAlertState?
    @Published var crashReportAlert = false
    @Published var navigationCommand: NavigationCommand?

    // MARK: - Private state

    private var cancellables = Set<AnyCancellable>()
    private var streamTask: Task<Void, Never>?
    private var apsDeviceToken: String?
    private var apsDeviceId: String?
    private var apsDeviceName: String?
    private var activeConnection: ConnectionInfo?
    private let synthesizer = AVSpeechSynthesizer()

    struct CertificateAlertState: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let delegate: HTTPClientDelegate
    }

    init() {
        setupTracker()
        startSSEListening()
        setupCrashReportCheck()
        setupNotificationHandling()

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("apsRegistered"),
            object: nil,
            queue: nil
        ) { [weak self] note in
            let deviceToken = note.userInfo?["deviceToken"] as? String
            let deviceId = note.userInfo?["deviceId"] as? String
            let deviceName = note.userInfo?["deviceName"] as? String
            Task { @MainActor in
                self?.handleApsRegistration(deviceToken: deviceToken, deviceId: deviceId, deviceName: deviceName)
            }
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

    // MARK: - Network Tracker

    private func setupTracker() {
        NotificationCenter.default.addObserver(
            forName: .evaluateServerTrust,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard
                let summary = notification.userInfo?["summary"] as? String,
                let domain = notification.userInfo?["domain"] as? String,
                let delegate = notification.object as? HTTPClientDelegate
            else { return }
            Task { @MainActor in
                self?.handleCertificateTrust(
                    summary: summary,
                    domain: domain,
                    delegate: delegate,
                    messageTemplateKey: "ssl_certificate_invalid"
                )
            }
        }

        NotificationCenter.default.addObserver(
            forName: .evaluateCertificateMismatch,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard
                let summary = notification.userInfo?["summary"] as? String,
                let domain = notification.userInfo?["domain"] as? String,
                let delegate = notification.object as? HTTPClientDelegate
            else { return }
            Task { @MainActor in
                self?.handleCertificateTrust(
                    summary: summary,
                    domain: domain,
                    delegate: delegate,
                    messageTemplateKey: "ssl_certificate_no_match"
                )
            }
        }

        NotificationCenter.default.addObserver(
            forName: .acceptedServerCertificatesChanged,
            object: nil,
            queue: nil
        ) { _ in
            Task { @MainActor in
                await WatchMessageService.singleton.syncPreferencesToWatch()
                await NetworkTracker.shared.restartTracking()
            }
        }

        Preferences.shared.$currentHomePreferences
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { homeSettings in
                let localConnectionConfig = homeSettings.localConnectionConfig
                let remoteConnectionConfig = homeSettings.remoteConnectionConfig
                let demomode = homeSettings.demomode
                let sseCommandItem = homeSettings.sseCommandItem

                Task {
                    if demomode {
                        await NetworkTracker.shared.startTracking(connectionConfigurations: [
                            ConnectionConfiguration(
                                url: "https://demo.openhab.org",
                                username: "",
                                password: "",
                                priority: 0
                            )
                        ])
                    } else {
                        await NetworkTracker.shared.startTracking(connectionConfigurations: [
                            localConnectionConfig,
                            remoteConnectionConfig
                        ])
                        await ItemEventStream.trackItems(sseCommandItem.isEmpty ? [] : [sseCommandItem])
                    }
                }
            }
            .store(in: &cancellables)

        MainActorNetworkTracker.shared.$activeConnection
            .receive(on: DispatchQueue.main)
            .sink { [weak self] activeConnection in
                if let activeConnection {
                    self?.activeConnection = activeConnection
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Certificate Trust

    private func handleCertificateTrust(summary: String, domain: String, delegate: HTTPClientDelegate, messageTemplateKey: String) {
        let title = NSLocalizedString("ssl_certificate_warning", comment: "")
        let message = String(format: NSLocalizedString(messageTemplateKey, comment: ""), summary, domain)
        certificateAlert = CertificateAlertState(title: title, message: message, delegate: delegate)
    }

    func certificateAlertAction(_ result: CertificateEvaluateResult) {
        certificateAlert?.delegate.completeEvaluation(result)
        certificateAlert = nil
    }

    // MARK: - Crash Report

    private func setupCrashReportCheck() {
        if Crashlytics.crashlytics().didCrashDuringPreviousExecution(), !Preferences.shared.sendCrashReports {
            crashReportAlert = true
        }
    }

    func enableCrashReporting() {
        Preferences.shared.sendCrashReports = true
        Crashlytics.crashlytics().sendUnsentReports()
    }

    func deleteCrashReports() {
        Crashlytics.crashlytics().deleteUnsentReports()
    }

    // MARK: - APS Registration

    private func handleApsRegistration(deviceToken: String?, deviceId: String?, deviceName: String?) {
        Logger.viewController.info("handleApsRegistration")
        apsDeviceToken = deviceToken
        apsDeviceId = deviceId
        apsDeviceName = deviceName
        subscribeToOpenhabConnectionChanges()
    }

    private func subscribeToOpenhabConnectionChanges() {
        struct UuidWithConnection: Hashable, Equatable {
            let uuid: UUID
            let connection: ConnectionConfiguration
        }

        let storedOpenHabConnections = Preferences.shared.$storedHomes
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .map { updatedPreferences in
                Set<UuidWithConnection>(updatedPreferences.compactMap { storedWithUuid in
                    let (uuid, homeConfig) = storedWithUuid
                    guard let connection = Preferences.shared.getNotificationConnection(of: homeConfig) else { return nil }
                    return UuidWithConnection(uuid: uuid, connection: connection)
                })
            }

        let connectionsWithPreviousValues = storedOpenHabConnections
            .scan((previous: Set<UuidWithConnection>(), current: Set<UuidWithConnection>())) { previous, current in
                (previous: previous.current, current: current)
            }

        let differences = connectionsWithPreviousValues.map { (previous, current) in
            (newValues: current.subtracting(previous), deletedValues: previous.subtracting(current))
        }

        differences.sink { [weak self] diff in
            Logger.viewController.info("openhabConnectionSubscription updated")
            for newHome in diff.newValues {
                Logger.viewController.info("openhabConnectionSubscription uuid \(newHome.uuid) registering for push notifications")
                self?.registerHome(uuid: newHome.uuid, connection: newHome.connection)
            }
            for deletedHome in diff.deletedValues {
                Logger.viewController.warning("APNS Deregistration is missing (wanted to deregister \(deletedHome.connection.url))")
            }
        }
        .store(in: &cancellables)
    }

    private func registerHome(uuid: UUID, connection: ConnectionConfiguration) {
        guard let deviceId = apsDeviceId,
              let deviceToken = apsDeviceToken,
              let deviceName = apsDeviceName else {
            Logger.viewController.fault("Cannot register homes for push notifications, no notification registration data available")
            return
        }
        Logger.viewController.info("Registering notifications with \(connection.url)")
        _ = registerHome(uuid, connection, deviceToken, deviceId, deviceName)
    }

    private func registerHome(_ uuid: UUID, _ config: ConnectionConfiguration, _ deviceToken: String, _ deviceId: String, _ deviceName: String) -> Task<Void, Never> {
        Task {
            do {
                let client = HTTPClient(connectionConfiguration: config)
                if let cloudUserId = try await client.register(prefsURL: config.url, deviceToken: deviceToken, deviceId: deviceId, deviceName: deviceName) {
                    Preferences.shared.setCloudUserId(cloudUserId, for: uuid)
                    Logger.viewController.info("my.openHAB registration succeeded with cloudUserId \(cloudUserId)")
                }
                Logger.viewController.info("my.openHAB registration succeeded without cloudUserId")
            } catch {
                Logger.viewController.error("my.openHAB registration failed \(error.localizedDescription)")
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
               let targetHome = Preferences.shared.storedHome(forCloudUserId: cloudUserId),
               Preferences.shared.currentHomePreferences.remoteConnectionConfig.cloudUserId != cloudUserId {
                await NetworkTracker.shared.stopTracking()
                Logger.viewController.info("Switching to home \(targetHome.id)")
                Preferences.shared.switchActiveHome(to: targetHome.id)
            }
            await NetworkTracker.shared.startTracking(connectionConfigurations:
                [
                    Preferences.shared.currentHomePreferences.localConnectionConfig,
                    Preferences.shared.currentHomePreferences.remoteConnectionConfig
                ]
            )
            _ = await NetworkTracker.shared.waitForActiveConnection()
            handleNotificationInternal(action)
        }
    }

    private func handleNotificationInternal(_ action: String?) {
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
                Logger.viewController.info("Sending command")
                try await NetworkTracker.shared.send(to: item, command: command, deviceId: deviceId)
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
                Logger.viewController.info("Executing rule \(uuid)")
                try await NetworkTracker.shared.runNow(ruleUID: uuid, payload: properties)
                Logger.viewController.info("Request succeeded")
            } catch let error as NetworkTrackerError {
                displayErrorNotification("\(error.localizedDescription)")
            } catch {
                Logger.viewController.error("Could not send data \(error.localizedDescription)")
                displayErrorNotification("Request to server failed: \(error.localizedDescription)")
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
            UIApplication.shared.isIdleTimerDisabled = !enabled
        case let .brightness(value):
            UIScreen.main.brightness = value
        case let .tts(text, language, voiceName):
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
            synthesizer.speak(utterance)
        }
    }
}

// MARK: - Kingfisher authentication

extension AppServicesViewModel: AuthenticationChallengeResponsible {
    nonisolated func downloader(_ downloader: ImageDownloader,
                                didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        await onReceiveSessionChallenge(with: challenge)
    }

    nonisolated func downloader(_ downloader: ImageDownloader,
                                task: URLSessionTask,
                                didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        await onReceiveSessionTaskChallenge(with: challenge)
    }
}

// MARK: - Notification name for routing

extension Notification.Name {
    static let openHABHandleNotificationAction = Notification.Name("openHABHandleNotificationAction")
}
