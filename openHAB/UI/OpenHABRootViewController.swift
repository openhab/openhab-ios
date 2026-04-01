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

import Combine
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

enum TargetController {
    case webview
    case settings
    case sitemap(String)
    case notifications
    case browser(String)
    case tile(String)
    case homeSelection
}

protocol ModalHandler: AnyObject {
    func modalDismissed(to: TargetController)
}

class HostingSitemapViewController: UIHostingController<SitemapNavigationView>, OpenHABViewable {
    private let viewModel: SitemapPageViewModel

    private weak var rootViewController: OpenHABRootViewController?

    init() {
        let viewModel = SitemapPageViewModel()
        self.viewModel = viewModel
        super.init(rootView: SitemapNavigationView(viewModel: viewModel) {})
    }

    @available(*, unavailable)
    @objc dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Hide UIKit navigation bar since SwiftUI now handles navigation
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ensure UIKit navigation bar stays hidden when transitioning from other views
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    func setRootViewController(_ rootViewController: OpenHABRootViewController) {
        self.rootViewController = rootViewController
        // Update the closure after initialization
        rootView = SitemapNavigationView(viewModel: viewModel) { [weak self] in
            self?.rootViewController?.showSideMenu()
        }
    }

    func getSitemapTitle() -> String {
        viewModel.pageTitle
    }

    func viewName() -> String { "sitemap" }

    nonisolated func reloadView() {
        Task { @MainActor in
            await viewModel.reload()
        }
    }

    func pushSitemap(name: String, path: String?) async {
        // Implement pushing logic into SitemapPageViewModel
        await viewModel.pushSitemap(name: name, path: path)
    }

    @MainActor
    func refreshOnForegroundIfNeeded() {
        // Avoid restarting the very first page load on initial app activation.
        guard viewModel.currentPage != nil || !viewModel.isLoading else { return }
        viewModel.refreshOnForeground()
    }

    // swiftlint:disable:next  function_parameter_count
    func showPopupMessage(seconds: Double,
                          title: String,
                          message: String,
                          theme: Theme,
                          viewTapAction: (() -> Void)?,
                          buttonTitle: String,
                          buttonAction: (() -> Void)?) {}

    func hidePopupMessages() {}
}

// MARK: - Hosting Web View Controller (SwiftUI WebView wrapped for UIKit)

class HostingWebViewController: UIViewController, OpenHABViewable {
    let webViewModel = OpenHABWebViewModel()
    private var hostingController: UIHostingController<AnyView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        let container = OpenHABWebViewContainer(viewModel: webViewModel)
        let hosting = UIHostingController(rootView: AnyView(container))
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hosting.didMove(toParent: self)
        hostingController = hosting
    }

    func viewName() -> String { "web" }

    nonisolated func reloadView() {
        Task { @MainActor in
            webViewModel.reloadView()
        }
    }

    func loadWebView(force: Bool = false, path: String? = nil) {
        webViewModel.loadWebView(force: force, path: path)
    }

    func navigateCommand(_ command: String) {
        webViewModel.navigateCommand(command)
    }

    // swiftlint:disable:next  function_parameter_count
    func showPopupMessage(seconds: Double,
                          title: String,
                          message: String,
                          theme: Theme,
                          viewTapAction: (() -> Void)?,
                          buttonTitle: String,
                          buttonAction: (() -> Void)?) {
        var config = SwiftMessages.Config()
        if seconds >= 0 {
            config.duration = .seconds(seconds: seconds)
        } else {
            config.duration = .forever
        }
        config.presentationStyle = .bottom
        config.presentationContext = .view(view)
        SwiftMessages.hideAll()
        SwiftMessages.show(config: config) {
            let msgView = MessageView.viewFromNib(layout: .cardView)
            msgView.configureTheme(theme)
            msgView.configureContent(title: title, body: message)
            msgView.button?.setTitle(buttonTitle, for: .normal)
            msgView.buttonTapHandler = { _ in
                SwiftMessages.hide()
                buttonAction?()
            }
            msgView.tapHandler = { _ in
                viewTapAction?()
            }
            return msgView
        }
    }

    func hidePopupMessages() {
        SwiftMessages.hideAll()
    }
}

// MARK: - Root View Controller (delegates to AppServicesViewModel)

class OpenHABRootViewController: UIViewController {
    var currentView: (any UIViewController & OpenHABViewable)!
    var isDemoMode = false
    var cancellables = Set<AnyCancellable>()
    private let currentViewState = CurrentViewState()
    private var becameActiveWhileSideMenuVisible = false
    private let appServices = AppServicesViewModel()

    private var networkStatusButton: UIButton = .init(type: .custom)

    private lazy var webViewController: HostingWebViewController = {
        let controller = HostingWebViewController()
        controller.webViewModel.onExitToApp = { [weak self] in
            self?.showSideMenu()
        }
        return controller
    }()

    lazy var sitemapViewController: any (UIViewController & OpenHABViewable) = {
        let controller = HostingSitemapViewController()
        controller.setRootViewController(self)
        return controller
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.viewController.info("OpenHABRootViewController viewDidLoad")
        setupSideMenu()
        addConnectionStatusIndication()
        observeNavigationCommands()

        #if DEBUG
        if ProcessInfo.processInfo.environment["UITest"] != nil {
            Preferences.shared.modifyActiveHome { homePreferences in
                homePreferences.demomode = true
            }
        }
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "HamburgerButton"
        #endif

        isDemoMode = Preferences.shared.currentHomePreferences.demomode
        switchToSavedView()
        observeAppForegroundForSideMenu()
    }

    override func viewWillAppear(_ animated: Bool) {
        Logger.viewController.info("OpenHABRootController viewWillAppear")
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
        if isDemoMode != Preferences.shared.currentHomePreferences.demomode {
            switchToSavedView()
            isDemoMode = Preferences.shared.currentHomePreferences.demomode
        }
        ImageDownloader.default.authenticationChallengeResponder = appServices
    }

    private func observeNavigationCommands() {
        appServices.$navigationCommand
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] command in
                guard let self else { return }
                switch command {
                case let .switchToWebView(path):
                    if currentView !== webViewController {
                        switchView(target: .webview)
                    }
                    if let path {
                        if path.starts(with: "/") {
                            webViewController.loadWebView(force: true, path: path)
                        } else {
                            webViewController.navigateCommand(path)
                        }
                    }
                case let .switchToSitemap(name, widgetId):
                    switchView(target: .sitemap(name))
                    if let widgetId {
                        Task { @MainActor in
                            await (self.sitemapViewController as? HostingSitemapViewController)?.pushSitemap(name: name, path: widgetId)
                        }
                    }
                }
                self.appServices.navigationCommand = nil
            }
            .store(in: &cancellables)
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
                    if let sitemapVC = self.currentView as? HostingSitemapViewController {
                        sitemapVC.refreshOnForegroundIfNeeded()
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func addConnectionStatusIndication() {
        MainActorNetworkTracker.shared.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self, let currentView else {
                    return
                }
                Logger.viewController.info("OpenHABWebViewController tracker status \(status.rawValue)")
                let retryButtonTitle: String = String(localized: "retry", comment: "retry connection")
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
                    let error: String = String(localized: "Error", comment: "")
                    let no_network: String = String(localized: "network_not_available", comment: "")
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
            guard let rootUrl = MainActorNetworkTracker.shared.activeConnection?.configuration.url else {
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
            // Handle webview navigation or state update
            Logger.viewController.debug("Dismissed to WebView")
            SideMenuManager.default.rightMenuNavigationController?.dismiss(animated: true)
            switchView(target: .webview)
        case .settings:
            Logger.viewController.debug("Dismissed to Settings")
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

    func showSideMenu() {
        Logger.viewController.info("OpenHABRootViewController showSideMenu")
        if let menu = SideMenuManager.default.rightMenuNavigationController {
            // don't try and push an already visible menu less you crash the app
            dismiss(animated: false) {
                var topMostViewController: UIViewController? =
                    UIApplication.shared.connectedScenes.flatMap { ($0 as? UIWindowScene)?.windows ?? [] }.last { $0.isKeyWindow }?.rootViewController

                while let presentedViewController = topMostViewController?.presentedViewController {
                    topMostViewController = presentedViewController
                }

                guard let presenter = topMostViewController else {
                    // swiftformat:disable:next redundantSelf
                    Logger.viewController.error("No valid view controller found to present side menu")
                    return
                }

                // Avoid trying to present the menu on itself
                if presenter == menu {
                    // swiftformat:disable:next redundantSelf
                    Logger.viewController.error("Cannot present side menu on itself")
                    return
                }

                presenter.present(menu, animated: true)
            }
        }
    }

    private func addView(viewController: UIViewController) {
        addChild(viewController)
        view.insertSubview(viewController.view, belowSubview: networkStatusButton)
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
            currentViewState.isWebViewActive = (targetView === webViewController)

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

}

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
                let hostingController = UIHostingController(rootView: NavigationView { SettingsView() })
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

