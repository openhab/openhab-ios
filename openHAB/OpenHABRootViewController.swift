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

import Combine
import FirebaseCrashlytics
import Foundation
import OpenHABCore
import os.log
import SafariServices
import SideMenu
import SwiftUI
import UIKit

enum TargetController {
    case webview
    case settings
    case sitemap(String)
    case notifications
    case browser(String)
    case tile(String)
}

protocol ModalHandler: AnyObject {
    func modalDismissed(to: TargetController)
}

private let logger = Logger(subsystem: "org.openhab.UI", category: "OpenHABRootViewController")

// swiftlint:disable type_body_length
class OpenHABRootViewController: UIViewController {
    var currentView: OpenHABViewController!
    var isDemoMode = false
    var cancellables = Set<AnyCancellable>()

    private lazy var webViewController: OpenHABWebViewController = {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        var viewController = storyboard.instantiateViewController(withIdentifier: "OpenHABWebViewController") as! OpenHABWebViewController
        return viewController
    }()

    private lazy var sitemapViewController: OpenHABSitemapViewController = {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        var viewController = storyboard.instantiateViewController(withIdentifier: "OpenHABPageViewController") as! OpenHABSitemapViewController
        return viewController
    }()

    private var activeConnection: ConnectionInfo?

    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("OpenHABRootViewController viewDidLoad", log: .default, type: .info)
        setupSideMenu()

        NotificationCenter.default.addObserver(self, selector: #selector(OpenHABRootViewController.handleApsRegistration(_:)), name: NSNotification.Name("apsRegistered"), object: nil)

        if Crashlytics.crashlytics().didCrashDuringPreviousExecution(), !Preferences.sendCrashReports {
            let alertController = UIAlertController(title: NSLocalizedString("crash_detected", comment: "").capitalized, message: NSLocalizedString("crash_reporting_info", comment: ""), preferredStyle: .alert)
            alertController.addAction(
                UIAlertAction(title: NSLocalizedString("activate", comment: ""), style: .default) { _ in
                    Preferences.sendCrashReports = true
                    Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
                    Crashlytics.crashlytics().sendUnsentReports()
                }
            )
            alertController.addAction(
                UIAlertAction(title: NSLocalizedString("privacy_policy", comment: ""), style: .default) { [weak self] _ in
                    let webViewController = SFSafariViewController(url: URL.privacyPolicy)
                    webViewController.configuration.barCollapsingEnabled = true
                    self?.present(webViewController, animated: true)
                }
            )
            alertController.addAction(
                UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .default) { _ in
                    Crashlytics.crashlytics().deleteUnsentReports()
                }
            )
            present(alertController, animated: true)
        }

        #if DEBUG
        if ProcessInfo.processInfo.environment["UITest"] != nil {
            // this is here to continue to make existing tests work, need to look at this later
            Preferences.demomode = true
        }
        // setup accessibilityIdentifiers for UITest
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "HamburgerButton"
        #endif
        // save this so we know if its changed later
        isDemoMode = Preferences.demomode
        switchToSavedView()
        setupTracker()
    }

    override func viewWillAppear(_ animated: Bool) {
        os_log("OpenHABRootController viewWillAppear", log: .viewCycle, type: .info)
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        // if we have turned demo mode off/on, reset view
        if isDemoMode != Preferences.demomode {
            switchToSavedView()
            isDemoMode = Preferences.demomode
        }
    }

    fileprivate func setupTracker() {
        let serverInfo = Publishers.CombineLatest(
            Preferences.$localConnectionConfig,
            Preferences.$remoteConnectionConfig
        )
        .eraseToAnyPublisher()

//        let misc = Publishers.CombineLatest3(
//            Preferences.$demomode,
//        )
//        .eraseToAnyPublisher()

        // Register for certificate trust notifications
        NotificationCenter.default.addObserver(
            forName: .evaluateServerTrust,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            self?.handleCertificateTrust(notification, message: NSLocalizedString("ssl_certificate_invalid", comment: ""))
        }

        NotificationCenter.default.addObserver(
            forName: .evaluateCertificateMismatch,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            self?.handleCertificateTrust(notification, message: NSLocalizedString("ssl_certificate_no_match", comment: ""))
        }

        NotificationCenter.default.addObserver(
            forName: .acceptedServerCertificatesChanged,
            object: nil,
            queue: nil
        ) { _ in
            WatchMessageService.singleton.syncPreferencesToWatch()
            NetworkTracker.shared.restartTracking()
        }

        Publishers.CombineLatest(serverInfo, Preferences.$demomode)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main) // ensures if multiple values are saved, we get called once
            .sink { (serverInfoTuple, miscTuple) in
                let (localConnectionConfig, remoteConnectionConfig) = serverInfoTuple
                let (demomode) = miscTuple
                if demomode {
                    NetworkTracker.shared.startTracking(connectionConfigurations: [
                        ConnectionConfiguration(
                            url: "https://demo.openhab.org",
                            username: "",
                            password: "",
                            priority: 0
                        )
                    ])
                } else {
                    NetworkTracker.shared.startTracking(connectionConfigurations: [localConnectionConfig, remoteConnectionConfig])
                }
            }
            .store(in: &cancellables)

        NetworkTracker.shared.$activeConnection
            .receive(on: DispatchQueue.main)
            .sink { [weak self] activeConnection in
                if let activeConnection {
                    self?.activeConnection = activeConnection
                }
            }
            .store(in: &cancellables)
    }

    fileprivate func setupSideMenu() {
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

        let networkTracker = NetworkTracker.shared
        let drawerView = DrawerView { mode in
            self.handleDismiss(mode: mode)
        }
        .environmentObject(networkTracker)
        let hostingController = UIHostingController(rootView: drawerView)
        let menu = SideMenuNavigationController(rootViewController: hostingController)

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
                os_log("openTileURL failed: no active connection URL", log: .default, type: .error)
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
            // Handle webview navigation or state update
            print("Dismissed to WebView")
            SideMenuManager.default.rightMenuNavigationController?.dismiss(animated: true)
            switchView(target: .webview)
        case .settings:
            print("Dismissed to Settings")
            SideMenuManager.default.rightMenuNavigationController?.dismiss(animated: true) {
                self.modalDismissed(to: .settings)
            }
        case let .sitemap(sitemap):
            Preferences.defaultSitemap = sitemap
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
        }
    }

    @objc
    func rightDrawerButtonPress(_ sender: Any?) {
        showSideMenu()
    }

    @objc
    func handleApsRegistration(_ note: Notification?) {
        logger.info("handleApsRegistration")
        let theData = note?.userInfo
        if theData != nil {
            guard let config = Preferences.getLowestPriorityOpenHABConnection() else { return }
            guard let deviceId = theData?["deviceId"] as? String, let deviceToken = theData?["deviceToken"] as? String, let deviceName = theData?["deviceName"] as? String else { return }
            logger.info("Registering notifications with \(config.url)")
            Task {
                do {
                    let client = HTTPClient(configuration: config)
                    try await client.register(prefsURL: config.url, deviceToken: deviceToken, deviceId: deviceId, deviceName: deviceName)
                    logger.info("my.openHAB registration succeeded")
                } catch {
                    logger.error("my.openHAB registration failed \(error.localizedDescription)")
                }
            }
        }
    }

    func handleNotification(action: String?) {
        guard let action else { return }

        let cmd = action.split(separator: ":").dropFirst().joined(separator: ":")

        switch true {
        case action.hasPrefix("ui"):
            uiCommandAction(cmd)
        case action.hasPrefix("command"):
            sendCommandAction(cmd)
        case action.hasPrefix("http"):
            httpCommandAction(action)
        case action.hasPrefix("app"):
            appCommandAction(action)
        case action.hasPrefix("rule"):
            ruleCommandAction(action)
        default:
            return
        }
    }

    // Helper function to safely call the completion handler on the main thread
    private func callCompletionHandler(_ completionHandler: (() -> Void)?) {
        if let completionHandler {
            DispatchQueue.main.async {
                completionHandler()
            }
        }
    }

    private func uiCommandAction(_ command: String) {
        os_log("navigateCommandAction:  %{PUBLIC}@", log: .notifications, type: .info, command)
        let regexPattern = /^(\/basicui\/app\\?.*|\/.*|.*)$/
        if let firstMatch = command.firstMatch(of: regexPattern) {
            let path = String(firstMatch.1)
            os_log("navigateCommandAction path:  %{PUBLIC}@", log: .notifications, type: .info, path)
            if path.starts(with: "/basicui/app?") {
                if currentView != sitemapViewController {
                    switchView(target: .sitemap(""))
                }
                if let urlComponents = URLComponents(string: path) {
                    let queryItems = urlComponents.queryItems
                    let sitemap = queryItems?.first { $0.name == "sitemap" }?.value
                    let subview = queryItems?.first { $0.name == "w" }?.value
                    if let sitemap {
                        Task {
                            await sitemapViewController.pushSitemap(name: sitemap, path: subview)
                        }
                    }
                }
            } else {
                if currentView != webViewController {
                    switchView(target: .webview)
                }
                if path.starts(with: "/") {
                    // have the webview load this path itself
                    webViewController.loadWebView(force: true, path: path)
                } else {
                    // have the mainUI handle the navigation
                    webViewController.navigateCommand(path)
                }
            }
        } else {
            os_log("Invalid regex: %{PUBLIC}@", log: .notifications, type: .error, command)
        }
    }

    private func sendCommandAction(_ action: String) {
        let components = action.split(separator: ":")
        guard components.count == 2 else {
            return
        }

        let itemName = String(components[0])
        let itemCommand = String(components[1])
        Task {
            do {
                logger.info("Sending command")
                try await NetworkTracker.shared.send(to: itemName, command: itemCommand)
            } catch NetworkTrackerError.noActiveConnection {
                displayErrorNotification("Could not find server")
            } catch {
                displayErrorNotification("Failed to establish a connection: \(error.localizedDescription)")
                // TODO:
                //            logger.error("Could not send data \(error.localizedDescription)")
                //
                //            self.displayErrorNotification("Request to \(url) failed: \(error.localizedDescription)")
            }
        }
    }

    private func displayErrorNotification(_ message: String, completionHandler: (() -> Void)? = nil) {
        let content = UNMutableNotificationContent()
        content.title = "Could not send command"
        content.body = message
        content.sound = UNNotificationSound.default

        // Create the request
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        // Schedule the request with the notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }

    private func httpCommandAction(_ command: String) {
        if let url = URL(string: command) {
            let vc = SFSafariViewController(url: url)
            present(vc, animated: true)
        }
    }

    private func appCommandAction(_ command: String) {
        let content = command.dropFirst(4) // Remove "app:"
        let pairs = content.split(separator: ",")
        for pair in pairs {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            guard keyValue.count == 2 else { continue }
            if keyValue[0] == "ios" {
                if let url = URL(string: String(keyValue[1])) {
                    os_log("appCommandAction opening %{public}@ %{public}@", log: .default, type: .error, String(keyValue[0]), String(keyValue[1]))
                    UIApplication.shared.open(url)
                    return
                }
            }
        }
    }

    private func ruleCommandAction(_ command: String) {
        let components = command.split(separator: ":", maxSplits: 2)

        guard components.count == 3, components[0] == "rule" else { return }

        let uuid = String(components[1])
        let propertiesString = String(components[2])

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
                logger.error("Sending command")
                try await NetworkTracker.shared.runNow(ruleUID: uuid, payload: properties)
                logger.info("Request succeeded")
            } catch let error as NetworkTrackerError {
                displayErrorNotification("\(error.localizedDescription)")
            } catch {
                logger.error("Could not send data \(error.localizedDescription)")
                displayErrorNotification("Request to server failed: \(error.localizedDescription)")
            }
        }
    }

    func showSideMenu() {
        os_log("OpenHABRootViewController showSideMenu", log: .viewCycle, type: .info)
        if let menu = SideMenuManager.default.rightMenuNavigationController {
            // don't try and push an already visible menu less you crash the app
            dismiss(animated: false) {
                var topMostViewController: UIViewController? =
                    UIApplication.shared.connectedScenes.flatMap { ($0 as? UIWindowScene)?.windows ?? [] }.last { $0.isKeyWindow }?.rootViewController

                while let presentedViewController = topMostViewController?.presentedViewController {
                    topMostViewController = presentedViewController
                }
                topMostViewController?.present(menu, animated: true)
            }
        }
    }

    private func addView(viewController: UIViewController) {
        addChild(viewController)
        view.addSubview(viewController.view)
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
        let targetView: OpenHABViewController

        switch target {
        case .sitemap:
            targetView = sitemapViewController
        case .webview:
            targetView = webViewController
        default:
            return
        }

        if currentView != targetView {
            if let currentView {
                removeView(viewController: currentView)
            }
            addView(viewController: targetView)
            currentView = targetView

            // Don't save our view in demo mode
            if !Preferences.demomode {
                Preferences.defaultView = currentView.viewName()
            }
        } else {
            // if we hit the menu item again while on the view, trigger a reload
            currentView.reloadView()
        }

        // Make sure we reset any views that may be pushed
        navigationController?.popToRootViewController(animated: true)
    }

    private func switchToSavedView() {
        if Preferences.demomode {
            switchView(target: .sitemap(""))
        } else {
            os_log("OpenHABRootViewController switchToSavedView %@", log: .viewCycle, type: .info, Preferences.defaultView == "sitemap" ? "sitemap" : "web")
            switchView(target: Preferences.defaultView == "sitemap" ? .sitemap("") : .webview)
        }
    }

    @objc func handleCertificateTrust(_ notification: Notification, message: String) {
        guard let summary = notification.userInfo?["summary"] as? String,
              let domain = notification.userInfo?["domain"] as? String,
              let client = notification.object as? HTTPClient else { return }
        let title = NSLocalizedString("ssl_certificate_warning", comment: "")
        let message = String(format: NSLocalizedString(message, comment: ""), summary, domain)
        DispatchQueue.main.async {
            // Show alert to user
            let alert = UIAlertController(
                title: title,
                message: message,
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "Always", style: .default) { _ in
                client.completeEvaluation(.permitAlways)
            })

            alert.addAction(UIAlertAction(title: "Once", style: .default) { _ in
                client.completeEvaluation(.permitOnce)
            })

            alert.addAction(UIAlertAction(title: "Deny", style: .cancel) { _ in
                client.completeEvaluation(.deny)
            })

            self.present(alert, animated: true)
        }
    }
}

// swiftlint:enable type_body_length

// MARK: - UISideMenuNavigationControllerDelegate

extension OpenHABRootViewController: SideMenuNavigationControllerDelegate {
    nonisolated func sideMenuWillAppear(menu: SideMenuNavigationController, animated: Bool) {
        os_log("OpenHABRootViewController sideMenuWillAppear", log: .viewCycle, type: .info)
    }
}

// MARK: - ModalHandler

extension OpenHABRootViewController: ModalHandler {
    nonisolated func modalDismissed(to: TargetController) {
        Task { @MainActor in
            switch to {
            case .sitemap:
                switchView(target: to)
            case .settings:
                let hostingController = UIHostingController(rootView: SettingsView())
                navigationController?.pushViewController(hostingController, animated: true)
            case .notifications:
                let hostingController = UIHostingController(rootView: NotificationsView())
                navigationController?.pushViewController(hostingController, animated: true)
            case .webview:
                switchView(target: to)
            case .browser:
                break
            case let .tile(urlString):
                openTileURL(urlString)
            }
        }
    }
}
