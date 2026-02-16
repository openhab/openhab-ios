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

import AsyncAlgorithms
import AVFoundation
import Combine
import FirebaseCrashlytics
import Kingfisher
import OpenHABCore
import os.log
import SafariServices
import SwiftUI

enum TargetController {
    case webview
    case settings
    case sitemap(String)
    case notifications
    case browser(String)
    case tile(String)
    case homeSelection
}

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

        // Subscribe to home preferences changes using AsyncChannel
        let trackerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            
            // Get the AsyncChannel for currentHomePreferences from the actor
            let preferencesChannel = await Preferences.shared.currentHomePreferencesChannel
            
            // Process initial value
            let initialSettings = await Preferences.shared.currentHomePreferences
            let localConnectionConfig = initialSettings.localConnectionConfig
            let remoteConnectionConfig = initialSettings.remoteConnectionConfig
            let demomode = initialSettings.demomode
            let sseCommandItem = initialSettings.sseCommandItem
            
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
            
            // Listen for changes with debouncing
            for await homeSettings in preferencesChannel.debounce(for: .milliseconds(500)) {
                let localConnectionConfig = homeSettings.localConnectionConfig
                let remoteConnectionConfig = homeSettings.remoteConnectionConfig
                let demomode = homeSettings.demomode
                let sseCommandItem = homeSettings.sseCommandItem
                
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
        
        cancellables.insert(AnyCancellable { trackerTask.cancel() })

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
        Task {
            if Crashlytics.crashlytics().didCrashDuringPreviousExecution(), !(await Preferences.shared.applicationPreferences.sendCrashReports) {
                crashReportAlert = true
            }
        }
    }

    func enableCrashReporting() {
        Task {
            await Preferences.shared.modifyApplicationPreferences(modificationFunction: { applicationPreferences in
                applicationPreferences.sendCrashReports = true
            })
            Crashlytics.crashlytics().sendUnsentReports()
        }
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

        // Cancel any existing subscription task
        let subscriptionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            
            // Get the AsyncChannel for storedHomes from the actor
            let storedHomesChannel = await Preferences.shared.storedHomesChannel
            
            var previousConnections = Set<UuidWithConnection>()
            
            // Process initial value
            let initialHomes = await Preferences.shared.storedHomes
            var initialConnections = Set<UuidWithConnection>()
            for (uuid, homeConfig) in initialHomes {
                if let connection = await Preferences.shared.getNotificationConnection(of: homeConfig) {
                    initialConnections.insert(UuidWithConnection(uuid: uuid, connection: connection))
                }
            }
            
            // Register initial homes
            for newHome in initialConnections {
                Logger.viewController.info("openhabConnectionSubscription uuid \(newHome.uuid) registering for push notifications (initial)")
                self.registerHome(uuid: newHome.uuid, connection: newHome.connection)
            }
            previousConnections = initialConnections
            
            // Listen for changes with debouncing
            for await updatedHomes in storedHomesChannel.debounce(for: .seconds(1)) {
                Logger.viewController.info("openhabConnectionSubscription updated")
                
                // Map to connections using manual iteration for async calls
                var currentConnections = Set<UuidWithConnection>()
                for (uuid, homeConfig) in updatedHomes {
                    if let connection = await Preferences.shared.getNotificationConnection(of: homeConfig) {
                        currentConnections.insert(UuidWithConnection(uuid: uuid, connection: connection))
                    }
                }
                
                // Calculate differences
                let newValues = currentConnections.subtracting(previousConnections)
                let deletedValues = previousConnections.subtracting(currentConnections)
                
                // Register new homes
                for newHome in newValues {
                    Logger.viewController.info("openhabConnectionSubscription uuid \(newHome.uuid) registering for push notifications")
                    self.registerHome(uuid: newHome.uuid, connection: newHome.connection)
                }
                
                // Log deleted homes (deregistration not implemented)
                for deletedHome in deletedValues {
                    Logger.viewController.warning("APNS Deregistration is missing (wanted to deregister \(deletedHome.connection.url))")
                }
                
                previousConnections = currentConnections
            }
        }
        
        // Store the task in cancellables for proper cleanup
        // We can wrap it in an AnyCancellable for compatibility
        cancellables.insert(AnyCancellable { subscriptionTask.cancel() })
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
                    await Preferences.shared.setCloudUserId(cloudUserId, for: uuid)
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
               let targetHome = await Preferences.shared.storedHome(forCloudUserId: cloudUserId),
               await Preferences.shared.currentHomePreferences.remoteConnectionConfig.cloudUserId != cloudUserId {
                await NetworkTracker.shared.stopTracking()
                Logger.viewController.info("Switching to home \(targetHome.id)")
                await Preferences.shared.switchActiveHome(to: targetHome.id)
            }
            
            let currentPreferences = await Preferences.shared.currentHomePreferences
            await NetworkTracker.shared.startTracking(connectionConfigurations:
                [
                    currentPreferences.localConnectionConfig,
                    currentPreferences.remoteConnectionConfig
                ]
            )
            _ = await NetworkTracker.shared.waitForActiveConnection()
            handleNotificationInternal(action)
        }
    }

    private func handleNotificationInternal(_ action: String?) {
        Logger.viewController.info("handleNotificationInternal: \(action ?? "<none>")")

        guard let action else { return }
        let actionParts = action.split(separator: ":")
        let cmd = actionParts.dropFirst().joined(separator: ":")

        switch actionParts[0] {
        case "ui":
            uiCommandAction(cmd)
        case "command":
            sendCommandAction(cmd)
        case "http":
            httpCommandAction(action)
        case "app":
            appCommandAction(cmd)
        case "rule":
            ruleCommandAction(cmd)
        case "device":
            deviceAction(cmd)
        default:
            return
        }
    }

    private func uiCommandAction(_ command: String) {
        Logger.viewController.info("navigateCommandAction: \(command)")
        let regexPattern = /^(\/basicui\/app\\?.*|\/.*|.*)$/
        if let firstMatch = command.firstMatch(of: regexPattern) {
            let path = String(firstMatch.1)
            Logger.viewController.info("navigateCommandAction path: \(path)")
            if path.starts(with: "/basicui/app?") {
                Logger.viewController.info("Navigating to sitemap target")
                Task { @MainActor in
                    let defaultSitemap = await Preferences.shared.currentHomePreferences.defaultSitemap
                    guard let urlComponents = URLComponents(string: path) else {
                        Logger.viewController.warning("No parameters for specifying sitemap or widget to navigate to")
                        navigationCommand = .switchToSitemap(name: defaultSitemap, widgetId: nil)
                        return
                    }
                    let queryItems = urlComponents.queryItems
                    let sitemap = queryItems?.first { $0.name == "sitemap" }?.value
                    let widgetId = queryItems?.first { $0.name == "w" }?.value
                    navigationCommand = .switchToSitemap(name: sitemap ?? defaultSitemap, widgetId: widgetId)
                }
            } else {
                Logger.viewController.info("Navigating to webview target")
                if path.starts(with: "/") {
                    navigationCommand = .switchToWebView(path: path)
                } else {
                    navigationCommand = .switchToWebView(path: path)
                }
            }
        } else {
            Logger.viewController.error("Invalid regex: \(command)")
        }
    }

    private func sendCommandAction(_ action: String) {
        let components = action.split(separator: ":")
        guard components.count == 2 else { return }

        let itemName = String(components[0])
        let itemCommand = String(components[1])
        let deviceId = UIDevice.current.identifierForVendor?.uuidString
        Task {
            do {
                Logger.viewController.info("Sending command")
                try await NetworkTracker.shared.send(to: itemName, command: itemCommand, deviceId: deviceId)
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

    private func httpCommandAction(_ command: String) {
        if let url = URL(string: command) {
            let vc = SFSafariViewController(url: url)
            UIApplication.shared.firstKeyWindow?.rootViewController?.present(vc, animated: true)
        }
    }

    private func appCommandAction(_ command: String) {
        let pairs = command.split(separator: ",")
        for pair in pairs {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            if keyValue[0] == "ios" {
                if let url = URL(string: String(keyValue[1])) {
                    Logger.viewController.error("appCommandAction opening \(String(keyValue[0])) \(String(keyValue[1]))")
                    UIApplication.shared.open(url)
                    return
                }
            }
        }
    }

    private func deviceAction(_ action: String) {
        let cmdParts = action.split(separator: ":")
        if cmdParts.isEmpty { return }
        let command = cmdParts[0].lowercased()
        let arg1 = cmdParts.count > 1 ? cmdParts[1].lowercased() : ""
        switch command {
        case "screensaver":
            switch arg1 {
            case "activate":
                NotificationCenter.default.post(name: .activateScreenSaver, object: nil)
            case "disable":
                NotificationCenter.default.post(name: .disableScreenSaver, object: nil)
            case "wake":
                NotificationCenter.default.post(name: .wakeScreenSaver, object: nil)
            default:
                break
            }
        case "idletimer":
            switch arg1 {
            case "enable":
                UIApplication.shared.isIdleTimerDisabled = false
            case "disable":
                UIApplication.shared.isIdleTimerDisabled = true
            default:
                break
            }
        case "brightness":
            if let value = Double(arg1) {
                let target = min(max(value, 0.0), 1.0)
                UIScreen.main.brightness = target
            }
        case "tts":
            func normalizeVoiceName(from input: String) -> String {
                input
                    .lowercased()
                    .components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .joined()
            }

            let utterance = AVSpeechUtterance(string: arg1)
            if cmdParts.count > 3 {
                Logger.viewController.debug("Filtering voice \(cmdParts[2]) \(cmdParts[3])")
                let voice = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.lowercased() == cmdParts[2].lowercased() && normalizeVoiceName(from: $0.name) == normalizeVoiceName(from: String(cmdParts[3])) }
                if !voice.isEmpty {
                    Logger.viewController.debug("Setting custom voice \(voice[0].name)")
                    utterance.voice = voice[0]
                }
            } else if cmdParts.count > 2 {
                utterance.voice = AVSpeechSynthesisVoice(language: String(cmdParts[2]))
            }
            synthesizer.speak(utterance)
        default:
            break
        }
    }

    private func ruleCommandAction(_ command: String) {
        let components = command.split(separator: ":", maxSplits: 2)
        guard !components.isEmpty else {
            Logger.viewController.warning("No rule to execute found in action")
            return
        }

        let uuid = String(components[0])
        let propertiesString = if components.count > 1 { String(components[1]) } else { "" }

        let propertyPairs = propertiesString.split(separator: ",")
        var properties: [String: String] = [:]

        for pair in propertyPairs {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            if keyValue.count == 2 {
                let key = String(keyValue[0])
                let value = String(keyValue[1])
                properties[key] = value
            }
        }
        Task {
            do {
                Logger.viewController.error("Sending command")
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
