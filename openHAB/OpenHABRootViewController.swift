// Copyright (c) 2010-2024 Contributors to the openHAB project
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

struct CommandItem: CommItem {
    var link: String
}

class OpenHABRootViewController: UIViewController {
    var currentView: OpenHABViewController!
    var isDemoMode = false

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

    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

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

        // ready for push notifications
        NotificationCenter.default.addObserver(self, selector: #selector(handleApnsMessage(notification:)), name: .apnsReceived, object: nil)
        // check if we were launched with a notification
        if let userInfo = appData?.lastNotificationInfo {
            handleNotification(userInfo)
        }
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

        let drawerView = DrawerView { mode in
            self.handleDismiss(mode: mode)
        }
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
        if !urlString.isEmpty {
            let url: URL? = if urlString.hasPrefix("http") {
                URL(string: urlString)
            } else {
                Endpoint.resource(openHABRootUrl: appData?.openHABRootUrl ?? "", path: urlString.prepare()).url
            }
            openURL(url: url)
        }
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
            appData?.sitemapViewController?.pageUrl = ""
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
        os_log("handleApsRegistration", log: .notifications, type: .info)
        let theData = note?.userInfo
        if theData != nil {
            let prefsURL = Preferences.remoteUrl
            if prefsURL.contains("openhab.org") {
                guard let deviceId = theData?["deviceId"] as? String, let deviceToken = theData?["deviceToken"] as? String, let deviceName = theData?["deviceName"] as? String else { return }
                os_log("Registering notifications with %{PUBLIC}@", log: .notifications, type: .info, prefsURL)
                NetworkConnection.register(prefsURL: prefsURL, deviceToken: deviceToken, deviceId: deviceId, deviceName: deviceName) { response in
                    switch response.result {
                    case .success:
                        os_log("my.openHAB registration sent", log: .notifications, type: .info)
                    case let .failure(error):
                        os_log("my.openHAB registration failed %{PUBLIC}@ %d", log: .notifications, type: .error, error.localizedDescription, response.response?.statusCode ?? 0)
                    }
                }
            }
        }
    }

    @objc func handleApnsMessage(notification: Notification) {
        // actionIdentifier is the result of a action button being pressed
        if let userInfo = notification.userInfo {
            handleNotification(userInfo)
        }
    }

    private func handleNotification(_ userInfo: [AnyHashable: Any]) {
        // actionIdentifier is the result of a action button being pressed
        // if not actionIdentifier, then the notification was clicked, so use "on-click" if there
        if let action = userInfo["actionIdentifier"] as? String ?? userInfo["on-click"] as? String {
            let cmd = action.split(separator: ":").dropFirst().joined(separator: ":")
            if action.hasPrefix("ui") {
                uiCommandAction(cmd)
            } else if action.hasPrefix("command") {
                sendCommandAction(cmd)
            } else if action.hasPrefix("http") {
                httpCommandAction(action)
            } else if action.hasPrefix("app") {
                appCommandAction(action)
            } else if action.hasPrefix("rule") {
                ruleCommandAction(action)
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
                    let sitemap = queryItems?.first(where: { $0.name == "sitemap" })?.value
                    let subview = queryItems?.first(where: { $0.name == "w" })?.value
                    if let sitemap {
                        sitemapViewController.pushSitemap(name: sitemap, path: subview)
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
        if components.count == 2 {
            let itemName = String(components[0])
            let itemCommand = String(components[1])

            var cancelable: AnyCancellable?
            // makeConnectable() + connect() allows us to reference the cancelable var within our closure
            let state = OpenHABTracker.shared.$state.makeConnectable()
            // this will be called imediately after connecting for the initial state, otherwise it will wait for the state to change
            cancelable = state
                .sink { newState in
                    if let openHABUrl = newState.openHABUrl?.absoluteString {
                        os_log("Sending comand", log: .default, type: .error)
                        let client = HTTPClient(username: Preferences.username, password: Preferences.password)
                        client.doPost(baseURLs: [openHABUrl], path: "/rest/items/\(itemName)", body: itemCommand) { data, _, error in
                            if let error {
                                os_log("Could not send data %{public}@", log: .default, type: .error, error.localizedDescription)
                            } else {
                                os_log("Request succeeded", log: .default, type: .info)
                                if let data {
                                    os_log("Data: %{public}@", log: .default, type: .debug, String(data: data, encoding: .utf8) ?? "")
                                }
                            }
                        }
                    }
                    if let cancelable {
                        os_log("pushSitemap: canceling sink", log: .default, type: .error)
                        cancelable.cancel()
                    }
                }
            _ = state.connect()
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

        guard components.count == 3,
              components[0] == "rule" else {
            return
        }

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

        var jsonString = ""
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: properties, options: [.prettyPrinted])
            jsonString = String(data: jsonData, encoding: .utf8)!
        } catch {
            // nothing
        }

        var cancelable: AnyCancellable?
        // makeConnectable() + connect() allows us to reference the cancelable var within our closure
        let state = OpenHABTracker.shared.$state.makeConnectable()
        // this will be called imediately after connecting for the initial state, otherwise it will wait for the state to change
        cancelable = state
            .sink { newState in
                if let openHABUrl = newState.openHABUrl?.absoluteString {
                    os_log("Sending comand", log: .default, type: .error)
                    let client = HTTPClient(username: Preferences.username, password: Preferences.password)
                    client.doPost(baseURLs: [openHABUrl], path: "/rest/rules/rules/\(uuid)/runnow", body: jsonString) { data, _, error in
                        if let error {
                            os_log("Could not send data %{public}@", log: .default, type: .error, error.localizedDescription)
                        } else {
                            os_log("Request succeeded", log: .default, type: .info)
                            if let data {
                                os_log("Data: %{public}@", log: .default, type: .debug, String(data: data, encoding: .utf8) ?? "")
                            }
                        }
                    }
                }
                if let cancelable {
                    os_log("pushSitemap: canceling sink", log: .default, type: .error)
                    cancelable.cancel()
                }
            }
        _ = state.connect()
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
        let targetView =
            if case .sitemap = target {
                sitemapViewController
            } else {
                webViewController
            }

        if currentView != targetView {
            if currentView != nil {
                removeView(viewController: currentView)
            }
            addView(viewController: targetView)
            currentView = targetView
            appData?.currentView = target
            // Don't save our view in demo mode
            if !Preferences.demomode {
                Preferences.defaultView = currentView.viewName()
            }
        } else {
            // if we hit the menu item again while on the view, trigger a reload
            currentView.reloadView()
        }
        // make sure we reset any views that may be pushed
        currentView.navigationController?.popToRootViewController(animated: true)
    }

    private func switchToSavedView() {
        if Preferences.demomode {
            switchView(target: .sitemap(""))
        } else {
            os_log("OpenHABRootViewController switchToSavedView %@", log: .viewCycle, type: .info, Preferences.defaultView == "sitemap" ? "sitemap" : "web")
            switchView(target: Preferences.defaultView == "sitemap" ? .sitemap("") : .webview)
        }
    }
}

// MARK: - UISideMenuNavigationControllerDelegate

extension OpenHABRootViewController: SideMenuNavigationControllerDelegate {
    func sideMenuWillAppear(menu: SideMenuNavigationController, animated: Bool) {
        os_log("OpenHABRootViewController sideMenuWillAppear", log: .viewCycle, type: .info)
    }
}

// MARK: - ModalHandler

extension OpenHABRootViewController: ModalHandler {
    func modalDismissed(to: TargetController) {
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
