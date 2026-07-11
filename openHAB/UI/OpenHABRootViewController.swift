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
import Foundation
import Kingfisher
import OpenHABCore
import os.log
import SafariServices
import SFSafeSymbols
import SideMenu
import SwiftMessages
import SwiftUI
import UIKit
import UserNotifications

enum TargetController {
    case webview
    case settings
    case sitemap(String)
    case notifications
    case browser(String)
    case tile(String)
    case homeSelection
}

private struct TrackerStartupSettings: Equatable {
    let demomode: Bool
    let localConnectionConfig: ConnectionConfiguration
    let remoteConnectionConfig: ConnectionConfiguration
    let sseCommandItem: String

    @MainActor
    init(homeSettings: HomePreferences) {
        demomode = homeSettings.demomode
        localConnectionConfig = homeSettings.localConnectionConfig
        remoteConnectionConfig = homeSettings.remoteConnectionConfig
        sseCommandItem = homeSettings.sseCommandItem
    }

    static func == (lhs: TrackerStartupSettings, rhs: TrackerStartupSettings) -> Bool {
        lhs.demomode == rhs.demomode &&
            lhs.localConnectionConfig.trackerIdentity == rhs.localConnectionConfig.trackerIdentity &&
            lhs.remoteConnectionConfig.trackerIdentity == rhs.remoteConnectionConfig.trackerIdentity &&
            lhs.sseCommandItem == rhs.sseCommandItem
    }
}

private struct TrackerConnectionIdentity: Equatable {
    let url: String
    let username: String
    let password: String
    let alwaysSendBasicAuth: Bool
    let ignoreSSL: Bool
    let priority: Int
    let supportsNotifications: Bool
}

protocol ModalHandler: AnyObject {
    func modalDismissed(to: TargetController)
}

// MARK: - Search Controller Delegates

// swiftlint:disable type_body_length
class OpenHABRootViewController: UIViewController {
    var currentView: (any UIViewController & OpenHABViewable)!
    var isDemoMode = false
    var cancellables = Set<AnyCancellable>()
    private let currentViewState = CurrentViewState()
    private var streamTask: Task<Void, Never>?
    private var becameActiveWhileSideMenuVisible = false

    private var apsRegistrationData: [AnyHashable: Any]?

    private var networkStatusButton: UIButton = .init(type: .custom)

    private let transitionCoverView: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.isHidden = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var webViewController: OpenHABWebViewController = {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        return storyboard.instantiateViewController(withIdentifier: "OpenHABWebViewController") as! OpenHABWebViewController
    }()

    lazy var sitemapViewController: any (UIViewController & OpenHABViewable) = {
        let controller = HostingSitemapViewController()
        controller.setRootViewController(self)
        return controller
    }()

    private var activeConnection: ConnectionInfo?
    private var lastTrackerStartupSettings: TrackerStartupSettings?
    /// Tracks the active home's id to detect switches and navigate to the new home's default sitemap.
    private var lastActiveHomeId: UUID?
    private var synthesizer = AVSpeechSynthesizer()

    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.viewController.info("OpenHABRootViewController viewDidLoad")
        edgesForExtendedLayout = []
        setupSideMenu()
        addConnectionStatusIndication()

        NotificationCenter.default.addObserver(self, selector: #selector(OpenHABRootViewController.handleApsRegistration(_:)), name: NSNotification.Name("apsRegistered"), object: nil)

        if Crashlytics.crashlytics().didCrashDuringPreviousExecution(), !Preferences.shared.sendCrashReports {
            let alertController = UIAlertController(title: String(localized: "crash_detected", comment: "").capitalized, message: String(localized: "crash_reporting_info", comment: ""), preferredStyle: .alert)
            alertController.addAction(
                UIAlertAction(title: String(localized: "activate", comment: ""), style: .default) { _ in
                    Preferences.shared.sendCrashReports = true
                    Crashlytics.crashlytics().sendUnsentReports()
                }
            )
            alertController.addAction(
                UIAlertAction(title: String(localized: "privacy_policy", comment: ""), style: .default) { [weak self] _ in
                    let webViewController = SFSafariViewController(url: URL.privacyPolicy)
                    webViewController.configuration.barCollapsingEnabled = true
                    self?.present(webViewController, animated: true)
                }
            )
            alertController.addAction(
                UIAlertAction(title: String(localized: "cancel", comment: ""), style: .default) { _ in
                    Crashlytics.crashlytics().deleteUnsentReports()
                }
            )
            present(alertController, animated: true)
        }

        #if DEBUG
        if ProcessInfo.processInfo.environment["UITest"] != nil {
            // this is here to continue to make existing tests work, need to look at this later
            Preferences.shared.modifyActiveHome { homePreferences in
                homePreferences.demomode = true
            }
        }
        #endif
        // save this so we know if its changed later
        isDemoMode = Preferences.shared.currentHomePreferences.demomode
        // seed so the first publisher fire is not mistaken for a home switch
        lastActiveHomeId = Preferences.shared.currentHomePreferences.id

        view.addSubview(transitionCoverView)
        NSLayoutConstraint.activate([
            transitionCoverView.topAnchor.constraint(equalTo: view.topAnchor),
            transitionCoverView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            transitionCoverView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            transitionCoverView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        switchToSavedView()
        if currentView === webViewController {
            webViewController.prepareForDisplayTransition()
        }

        setupTracker()
        startSSEListening()
        observeAppForegroundForSideMenu()
    }

    override func viewWillAppear(_ animated: Bool) {
        Logger.viewController.info("OpenHABRootController viewWillAppear")
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
        // if we have turned demo mode off/on, reset view
        if isDemoMode != Preferences.shared.currentHomePreferences.demomode {
            switchToSavedView()
            isDemoMode = Preferences.shared.currentHomePreferences.demomode
        }
        // Restore correct nav bar state when returning from pushed screens (e.g. notifications, home
        // selection). Those screens call setNavigationBarHidden(false) before pushing; popping back
        // lands here but does not re-hide the bar, causing the UIKit hamburger and the SwiftUI one
        // inside SitemapNavigationView to appear simultaneously.
        if currentView === sitemapViewController {
            navigationController?.setNavigationBarHidden(true, animated: animated)
        }
        ImageDownloader.default.authenticationChallengeResponder = self
    }

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

    private func observeAppForegroundForSideMenu() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                let isSideMenuVisible = SideMenuManager.default.rightMenuNavigationController?.presentingViewController != nil
                if isSideMenuVisible {
                    becameActiveWhileSideMenuVisible = true
                    return
                }

                Task { @MainActor in
                    if let sitemapVC = currentView as? HostingSitemapViewController {
                        sitemapVC.refreshOnForegroundIfNeeded()
                    }
                }
            }
            .store(in: &cancellables)
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

    private func addConnectionStatusIndication() {
        MainActorNetworkTracker.shared.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self, let currentView else {
                    return
                }
                Logger.viewController.info("OpenHABWebViewController tracker status \(status.rawValue, privacy: .public)")
                let retryButtonTitle = String(localized: "retry", comment: "retry connection")
                switch status {
                case .started:
                    currentView.showPopupMessage(
                        seconds: -1,
                        title: String(localized: "no_connection_will_reconnect", comment: ""),
                        message: "",
                        theme: .warning,
                        viewTapAction: nil,
                        buttonTitle: retryButtonTitle
                    ) {
                        Task {
                            await NetworkTracker.shared.restartTracking()
                        }
                    }
                case .connecting:
                    currentView.showPopupMessage(
                        seconds: 60,
                        title: String(localized: "connecting", comment: ""),
                        message: "",
                        theme: .info,
                        viewTapAction: nil,
                        buttonTitle: "",
                        buttonAction: nil
                    )
                case .connected:
                    currentView.hidePopupMessages()
                case .stopped:
                    let error = String(localized: "Error", comment: "")
                    let no_network = String(localized: "network_not_available", comment: "")
                    currentView.showPopupMessage(
                        seconds: -1,
                        title: error,
                        message: no_network,
                        theme: .error,
                        viewTapAction: nil,
                        buttonTitle: retryButtonTitle
                    ) {
                        Task {
                            await NetworkTracker.shared.restartTracking()
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func setupTracker() {
        let serverInfo = Preferences.shared.currentHomePreferencesPublisher

        // Register for certificate trust notifications
        NotificationCenter.default.addObserver(
            forName: .evaluateServerTrust,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard
                let summary = notification.userInfo?["summary"] as? String,
                let domain = notification.userInfo?["domain"] as? String,
                let delegate = notification.object as? HTTPClientDelegate
            else {
                return
            }

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

            else {
                return
            }

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

        serverInfo.debounce(for: .milliseconds(500), scheduler: RunLoop.main) // ensures if multiple values are saved, we get called once
            .sink { [weak self] homeSettings in
                guard let self else { return }

                // Navigate to the new home's default view when the active home changes.
                let currentHomeId = homeSettings.id
                if lastActiveHomeId != currentHomeId {
                    lastActiveHomeId = currentHomeId
                    let defaultSitemap = homeSettings.defaultSitemap
                    let defaultView = homeSettings.defaultView
                    Logger.viewController.info("Home switched to \(homeSettings.homeName, privacy: .private), navigating to default view")
                    if defaultView == "sitemap" {
                        if currentView !== sitemapViewController {
                            switchView(target: .sitemap(defaultSitemap))
                        }
                        Task { @MainActor [weak self] in
                            await (self?.sitemapViewController as? HostingSitemapViewController)?
                                .pushSitemap(name: defaultSitemap, path: nil)
                        }
                    } else {
                        switchView(target: .webview)
                    }
                }

                let settings = TrackerStartupSettings(homeSettings: homeSettings)
                guard lastTrackerStartupSettings != settings else {
                    Logger.viewController.debug("Skipping duplicate tracker startup settings")
                    return
                }
                lastTrackerStartupSettings = settings

                let localConnectionConfig = settings.localConnectionConfig
                let remoteConnectionConfig = settings.remoteConnectionConfig
                let demomode = settings.demomode
                let sseCommandItem = settings.sseCommandItem

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

    private func setupSideMenu() {
        let hamburgerButtonItem: UIBarButtonItem
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .largeTitle)
        let buttonImage = UIImage(systemSymbol: .line3Horizontal, withConfiguration: imageConfig)
        let button = UIButton(type: .custom)
        button.setImage(buttonImage, for: .normal)
        button.addTarget(self, action: #selector(OpenHABRootViewController.rightDrawerButtonPress(_:)), for: .touchUpInside)
        hamburgerButtonItem = UIBarButtonItem(customView: button)
        hamburgerButtonItem.customView?.heightAnchor.constraint(equalToConstant: 30).isActive = true
        navigationItem.setRightBarButton(hamburgerButtonItem, animated: true)

        // Define the menus

        let presentationStyle: SideMenuPresentationStyle = .viewSlideOutMenuIn
        presentationStyle.presentingEndAlpha = 1
        presentationStyle.onTopShadowOpacity = 0.5
        var settings = SideMenuSettings()
        settings.presentationStyle = presentationStyle
        settings.statusBarEndAlpha = 0

        SideMenuManager.default.rightMenuNavigationController?.settings = settings

        let networkTracker = MainActorNetworkTracker.shared
        let drawerView = DrawerView { mode in
            self.handleDismiss(mode: mode)
        }
        .environmentObject(networkTracker)
        .environmentObject(currentViewState)
        let hostingController = UIHostingController(rootView: drawerView)
        let menu = SideMenuNavigationController(rootViewController: hostingController)
        menu.sideMenuDelegate = self

        SideMenuManager.default.rightMenuNavigationController = menu

        // Enable gestures. The left and/or right menus must be set up above for these to work.
        // Note that these continue to work on the Navigation Controller independent of the View Controller it displays!
        SideMenuManager.default.addPanGestureToPresent(toView: navigationController!.navigationBar)
        SideMenuManager.default.addScreenEdgePanGesturesToPresent(toView: navigationController!.view, forMenu: .right)
    }

    private func openTileURL(_ urlString: String) {
        // Use SFSafariViewController in SwiftUI with UIViewControllerRepresentable
        // Dependent on $OPENHAB_CONF/services/runtime.cfg
        // Can either be an absolute URL, a path (sometimes malformed)
        guard !urlString.isEmpty else { return }

        let url: URL?
        if urlString.hasPrefix("http") || urlString.hasPrefix("https") {
            url = URL(string: urlString)
        } else {
            guard let rootUrl = activeConnection?.configuration.url else {
                Logger.viewController.error("openTileURL failed: no active connection URL")
                return
            }
            url = Endpoint.resource(openHABRootUrl: rootUrl, path: urlString.prepare()).url
        }
        openURL(url: url)
    }

    private func openURL(url: URL?) {
        if let url {
            let config = SFSafariViewController.Configuration()
            config.entersReaderIfAvailable = true
            let vc = SFSafariViewController(url: url, configuration: config)
            present(vc, animated: true)
        }
    }

    private func handleDismiss(mode: TargetController) {
        switch mode {
        case .webview:
            let needsSwitch = currentView !== webViewController
            if needsSwitch {
                // Cover the root view so the dismiss animation doesn't expose the
                // old child view (e.g. SitemapView) while the menu slides away.
                // addView inserts at index 0, so transitionCoverView stays on top.
                webViewController.prepareForDisplayTransition()
                view.bringSubviewToFront(transitionCoverView)
                transitionCoverView.isHidden = false
                switchView(target: .webview)
            }
            SideMenuManager.default.rightMenuNavigationController?.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                // Re-tapping Home while already on it reloads.
                if !needsSwitch || !webViewController.hasLoadedPage {
                    webViewController.reloadView()
                }
                transitionCoverView.isHidden = true
            }
        case .settings:
            SideMenuManager.default.rightMenuNavigationController?.dismiss(animated: true) {
                self.modalDismissed(to: .settings)
            }
        case let .sitemap(sitemap):
            SideMenuManager.default.rightMenuNavigationController?.dismiss(animated: true) {
                self.modalDismissed(to: .sitemap(sitemap))
            }
        case .notifications:
            SideMenuManager.default.rightMenuNavigationController?.dismiss(animated: true) {
                self.modalDismissed(to: .notifications)
            }
        case let .browser(urlString):
            SideMenuManager.default.rightMenuNavigationController?.dismiss(animated: true) {
                self.modalDismissed(to: .browser(urlString))
            }
        case let .tile(urlString):
            SideMenuManager.default.rightMenuNavigationController?.dismiss(animated: true) {
                self.modalDismissed(to: .tile(urlString))
            }
        case .homeSelection:
            Logger.viewController.debug("Dismissed to Home Selection")
            SideMenuManager.default.rightMenuNavigationController?.dismiss(animated: true) {
                self.modalDismissed(to: .homeSelection)
            }
        }
    }

    @objc
    func rightDrawerButtonPress(_ sender: Any?) {
        showSideMenu()
    }

    @objc
    func handleApsRegistration(_ note: Notification?) {
        Logger.viewController.info("handleApsRegistration")
        apsRegistrationData = note?.userInfo
        subscribeToOpenhabConnectionChanges()
    }

    private func subscribeToOpenhabConnectionChanges() {
        struct UuidWithConnection: Hashable, Equatable {
            let uuid: UUID
            let connection: ConnectionConfiguration // not only URL, because auth and certs might be relevant for establishing the connection
        }

        let storedOpenHabConnections = Preferences.shared.$storedHomes
            .debounce(for: .seconds(1), scheduler: RunLoop.main) // avoid overexcited registrations / deregistrations in batch updates
            .map { updatedPreferences in // we want to recognize changes in the OpenHab URLs for any of the homes
                Set<UuidWithConnection>(updatedPreferences.compactMap { storedWithUuid in
                    let (uuid, homeConfig) = storedWithUuid
                    guard let connection = Preferences.shared.getNotificationConnection(of: homeConfig) else { return nil }
                    return UuidWithConnection(uuid: uuid, connection: connection)
                })
            }

        // create a tuple that lets us inspect the previous value
        let connectionsWithPreviousValues = storedOpenHabConnections
            .scan((previous: Set<UuidWithConnection>(), current: Set<UuidWithConnection>())) { previous, current in
                (previous: previous.current, current: current)
            }

        let differences = connectionsWithPreviousValues.map { (previous, current) in // diff set of previous and current OpenHab URLs
            (newValues: current.subtracting(previous), deletedValues: previous.subtracting(current))
        }

        let openhabConnectionSubscription = differences.sink { [weak self] diff in
            Logger.viewController.info("openhabConnectionSubscription updated")
            for newHome in diff.newValues {
                Logger.viewController.info("openhabConnectionSubscription registering home for push notifications")
                self?.registerHome(uuid: newHome.uuid, connection: newHome.connection)
            }
            for deletedHome in diff.deletedValues {
                // TODO: implement deregistration
                Logger.viewController.warning("APNS Deregistration is missing (wanted to deregister \(deletedHome.connection.publicLogURL, privacy: .public))")
            }
        }

        cancellables.insert(openhabConnectionSubscription)
    }

    private func registerHome(uuid: UUID, connection: ConnectionConfiguration) {
        guard let apsRegistrationData else {
            Logger.viewController.fault("Cannot register homes for push notifications, no notification registration data available")
            return
        }
        guard let deviceId = apsRegistrationData["deviceId"] as? String,
              let deviceToken = apsRegistrationData["deviceToken"] as? String,
              let deviceName = apsRegistrationData["deviceName"] as? String else {
            return
        }
        Logger.viewController.info("Registering notifications with \(connection.publicLogURL, privacy: .public)")
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

    func handleNotification(action: String?, cloudUserId: String?, notification: UNNotification? = nil) {
        guard let action else { return }

        Logger.viewController.info("handleNotification cloudUserId: \(cloudUserId ?? "<none>")")

        Task {
            if let cloudUserId, let targetHome = Preferences.shared.storedHome(forCloudUserId: cloudUserId), Preferences.shared.currentHomePreferences.remoteConnectionConfig.cloudUserId != cloudUserId {
                // if we need to switch homes, disconnnect the tracking first, and update preferences
                await NetworkTracker.shared.stopTracking()
                Logger.viewController.info("Switching to home \(targetHome.id)")
                Preferences.shared.switchActiveHome(to: targetHome.id)
            }
            // if the app was woken from a fully stopped state, network tracking might not be active yet
            await NetworkTracker.shared.startTracking(
                connectionConfigurations:
                [
                    Preferences.shared.currentHomePreferences.localConnectionConfig,
                    Preferences.shared.currentHomePreferences.remoteConnectionConfig
                ]
            )
            _ = await NetworkTracker.shared.waitForActiveConnection()
            handleNotificationInternal(action, notification: notification)
        }
    }

    private func handleNotificationInternal(_ action: String?, notification: UNNotification? = nil) {
        Logger.viewController.info("handleNotificationInternal: \(action ?? "<none>")")

        guard let action else { return }
        let actionParts = action.split(separator: ":")
        let cmd = actionParts.dropFirst().joined(separator: ":")

        switch actionParts[0] {
        case "ui":
            uiCommandAction(cmd)
        case "command":
            sendCommandAction(cmd, notification: notification)
        case "http":
            httpCommandAction(action)
        case "app":
            appCommandAction(cmd)
        case "rule":
            ruleCommandAction(cmd, notification: notification)
        case "device":
            deviceAction(cmd)
        default:
            return
        }
    }

    /// Helper function to safely call the completion handler on the main thread
    private func callCompletionHandler(_ completionHandler: (() -> Void)?) {
        if let completionHandler {
            DispatchQueue.main.async {
                completionHandler()
            }
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
                let defaultSitemap = Preferences.shared.currentHomePreferences.defaultSitemap
                guard let urlComponents = URLComponents(string: path) else {
                    Logger.viewController.warning("No parameters for specifying sitemap or widget to navigate to")
                    if currentView !== sitemapViewController {
                        switchView(target: .sitemap(defaultSitemap))
                    }
                    return
                }
                let queryItems = urlComponents.queryItems
                let sitemap = queryItems?.first { $0.name == "sitemap" }?.value
                let widgetId = queryItems?.first { $0.name == "w" }?.value
                if currentView !== sitemapViewController {
                    switchView(target: .sitemap(sitemap ?? defaultSitemap))
                }
                if let sitemap {
                    Task { @MainActor in
                        await (sitemapViewController as? HostingSitemapViewController)?.pushSitemap(name: sitemap, path: widgetId)
                    }
                }
            } else {
                Logger.viewController.info("Navigating to webview target")
                if currentView != webViewController {
                    switchView(target: .webview)
                }
                if path.starts(with: "/") {
                    Task {
                        // have the webview load this path itself
                        webViewController.loadWebView(force: true, path: path)
                    }
                } else {
                    // have the mainUI handle the navigation
                    webViewController.navigateCommand(path)
                }
            }
        } else {
            Logger.viewController.error("Invalid regex: \(command)")
        }
    }

    private func sendCommandAction(_ action: String, notification: UNNotification? = nil) {
        let components = action.split(separator: ":")
        guard components.count == 2 else {
            return
        }

        let itemName = String(components[0])
        let itemCommand = String(components[1])
        let deviceId = UIDevice.current.identifierForVendor?.uuidString
        Task {
            do {
                Logger.viewController.info("Sending command")
                try await NetworkTracker.shared.send(to: itemName, command: itemCommand, deviceId: deviceId)
            } catch NetworkTrackerError.noActiveConnection {
                displayErrorNotification("Could not find server")
                repostNotification(notification)
            } catch {
                displayErrorNotification("Failed to establish a connection: \(error.localizedDescription)")
                repostNotification(notification)
                Logger.viewController.error("Could not send data \(error.localizedDescription)")
            }
        }
    }

    private func displayErrorNotification(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Could not send command"
        content.body = message
        content.sound = UNNotificationSound.default

        // Schedule the request with the notification center
        // no error handler because it only printed and tended to crash in swift6
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    private func repostNotification(_ notification: UNNotification?) {
        guard let notification else { return }
        let original = notification.request.content
        let content = UNMutableNotificationContent()
        content.title = original.title
        content.subtitle = original.subtitle
        content.body = original.body
        content.sound = original.sound
        content.categoryIdentifier = original.categoryIdentifier
        content.userInfo = original.userInfo
        content.badge = original.badge
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: notification.request.identifier, content: content, trigger: nil))
    }

    private func httpCommandAction(_ command: String) {
        if let url = URL(string: command) {
            let vc = SFSafariViewController(url: url)
            present(vc, animated: true)
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
                view.window?.windowScene?.screen.brightness = target
            }
        case "tts":
            func normalizeVoiceName(from input: String) -> String {
                input
                    .lowercased()
                    .components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .joined()
            }
            Logger.viewController.debug("Attempting to speak text \(arg1)")
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
            // Reset synthesizer to recover from audio interruptions
            // (e.g. WebRTC audio in a WKWebView stealing the session).
            // Use .mixWithOthers so TTS coexists with WebRTC instead of
            // fighting for exclusive audio session control.
            synthesizer.stopSpeaking(at: .immediate)
            synthesizer = AVSpeechSynthesizer()
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default, options: .mixWithOthers)
                try audioSession.setActive(true)
            } catch {
                Logger.viewController.warning("Failed to configure audio session for TTS: \(error.localizedDescription)")
            }
            synthesizer.speak(utterance)
        default:
            break
        }
    }

    private func ruleCommandAction(_ command: String, notification: UNNotification? = nil) {
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
                repostNotification(notification)
            } catch {
                Logger.viewController.error("Could not send data \(error.localizedDescription)")
                displayErrorNotification("Request to server failed: \(error.localizedDescription)")
                repostNotification(notification)
            }
        }
    }

    func showSideMenu() {
        Logger.viewController.info("OpenHABRootViewController showSideMenu")
        guard let menu = SideMenuManager.default.rightMenuNavigationController else { return }
        guard menu.presentingViewController == nil else { return }

        var presenter: UIViewController = self
        while let presentedViewController = presenter.presentedViewController {
            presenter = presentedViewController
        }

        guard presenter !== menu else {
            Logger.viewController.error("Cannot present side menu on itself")
            return
        }

        presenter.present(menu, animated: true)
    }

    private func addView(viewController: UIViewController) {
        addChild(viewController)
        view.insertSubview(viewController.view, at: 0)
        viewController.view.frame = view.bounds
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        viewController.didMove(toParent: self)
    }

    private func removeView(viewController: UIViewController) {
        viewController.willMove(toParent: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
    }

    private func switchView(target: TargetController) {
        let targetView: any (UIViewController & OpenHABViewable)

        switch target {
        case let .sitemap(sitemap):
            Preferences.shared.modifyActiveHome { preferences in
                preferences.defaultSitemap = sitemap
            }
            targetView = sitemapViewController
        case .webview:
            targetView = webViewController
        default:
            return
        }

        if currentView !== targetView {
            if let currentView {
                removeView(viewController: currentView)
            }
            addView(viewController: targetView)
            currentView = targetView

            // Update webview active state
            currentViewState.isWebViewActive = (targetView == webViewController)

            // Don't save our view in demo mode
            if !Preferences.shared.currentHomePreferences.demomode {
                Preferences.shared.modifyActiveHome {
                    $0.defaultView = currentView.viewName()
                }
            }
        } else {
            // if we hit the menu item again while on the view, trigger a reload
            currentView.reloadView()
        }

        // Make sure we reset any views that may be pushed
        navigationController?.popToRootViewController(animated: true)
    }

    private func switchToSavedView() {
        if Preferences.shared.currentHomePreferences.demomode {
            switchView(target: .sitemap("demo"))
        } else {
            let defaultView = Preferences.shared.currentHomePreferences.defaultView
            let defaultSitemap = Preferences.shared.currentHomePreferences.defaultSitemap
            Logger.viewController.info("OpenHABRootViewController switchToSavedView \(defaultView == "sitemap" ? "sitemap/\(defaultSitemap)" : "web")")
            switchView(target: defaultView == "sitemap" ? .sitemap(defaultSitemap) : .webview)
        }
    }

    @MainActor
    @objc func handleCertificateTrust(_ notification: Notification, message: String) {
        guard let summary = notification.userInfo?["summary"] as? String,
              let domain = notification.userInfo?["domain"] as? String,
              let delegate = notification.object as? HTTPClientDelegate else { return }
        let title = String(localized: "ssl_certificate_warning", comment: "")
        let message = String(format: NSLocalizedString(message, comment: ""), summary, domain)
        DispatchQueue.main.async {
            // Show alert to user
            let alert = UIAlertController(
                title: title,
                message: message,
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "Always", style: .default) { _ in
                delegate.completeEvaluation(.permitAlways)
            })

            alert.addAction(UIAlertAction(title: "Once", style: .default) { _ in
                delegate.completeEvaluation(.permitOnce)
            })

            alert.addAction(UIAlertAction(title: "Deny", style: .cancel) { _ in
                delegate.completeEvaluation(.deny)
            })

            self.present(alert, animated: true)
        }
    }

    @MainActor
    @objc
    func handleCertificateTrust(summary: String, domain: String, delegate: HTTPClientDelegate, messageTemplateKey: String) {
        let title = String(localized: "ssl_certificate_warning", comment: "")
        let message = String(format: NSLocalizedString(messageTemplateKey, comment: ""), summary, domain)

        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Always", style: .default) { _ in
            delegate.completeEvaluation(.permitAlways)
        })

        alert.addAction(UIAlertAction(title: "Once", style: .default) { _ in
            delegate.completeEvaluation(.permitOnce)
        })

        alert.addAction(UIAlertAction(title: "Deny", style: .cancel) { _ in
            delegate.completeEvaluation(.deny)
        })

        var presenter: UIViewController = self
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(alert, animated: true)
    }
}

private extension ConnectionConfiguration {
    var trackerIdentity: TrackerConnectionIdentity {
        TrackerConnectionIdentity(
            url: url,
            username: username,
            password: password,
            alwaysSendBasicAuth: alwaysSendBasicAuth,
            ignoreSSL: ignoreSSL,
            priority: priority,
            supportsNotifications: supportsNotifications
        )
    }
}

// swiftlint:enable type_body_length

// MARK: - UISideMenuNavigationControllerDelegate

extension OpenHABRootViewController: SideMenuNavigationControllerDelegate {
    nonisolated func sideMenuWillAppear(menu: SideMenuNavigationController, animated: Bool) {
        Logger.viewController.info("OpenHABRootViewController sideMenuWillAppear")
    }

    nonisolated func sideMenuDidDisappear(menu: SideMenuNavigationController, animated: Bool) {
        Task { @MainActor in
            guard becameActiveWhileSideMenuVisible else { return }
            becameActiveWhileSideMenuVisible = false

            if let sitemapVC = currentView as? HostingSitemapViewController {
                sitemapVC.refreshOnForegroundIfNeeded()
            }
        }
    }
}

// MARK: - ModalHandler

extension OpenHABRootViewController: ModalHandler {
    nonisolated func modalDismissed(to: TargetController) {
        Task { @MainActor in
            switch to {
            case let .sitemap(sitemapName):
                switchView(target: to)
                await (sitemapViewController as? HostingSitemapViewController)?.pushSitemap(name: sitemapName, path: nil)
            case .settings:
                let hostingController = UIHostingController(rootView: NavigationStack { SettingsView() })
                present(hostingController, animated: true)
            case .notifications:
                let hostingController = UIHostingController(rootView: NotificationsView())
                navigationController?.setNavigationBarHidden(false, animated: true)
                navigationController?.pushViewController(hostingController, animated: true)
            case .webview:
                switchView(target: to)
            case .browser:
                break
            case let .tile(urlString):
                openTileURL(urlString)
            case .homeSelection:
                let hostingController = UIHostingController(rootView: HomeSelectionView())
                navigationController?.setNavigationBarHidden(false, animated: true)
                navigationController?.pushViewController(hostingController, animated: true)
            }
        }
    }
}

// MARK: Kingfisher authentication with URLCredential

extension OpenHABRootViewController: AuthenticationChallengeResponsible {
    func downloader(_ downloader: ImageDownloader,
                    didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        await onReceiveSessionChallenge(with: challenge)
    }

    func downloader(_ downloader: ImageDownloader,
                    task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        await onReceiveSessionTaskChallenge(with: challenge)
    }
}
