// Copyright (c) 2010-2020 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Alamofire
import AVFoundation
import AVKit
import DynamicButton
import Fuzi
import Kingfisher
import OpenHABCore
import os.log
import SideMenu
import SVGKit
import SwiftMessages
import UIKit

enum TargetController {
    case root
    case settings
    case notifications
    case habpanel
}

enum Action<I, O> {
    typealias Sync = (UIViewController, I) -> O
    typealias Async = (UIViewController, I, @escaping (O) -> Void) -> Void
}

protocol ModalHandler: AnyObject {
    func modalDismissed(to: TargetController)
}

struct SVGProcessor: ImageProcessor {
    // `identifier` should be the same for processors with the same properties/functionality
    // It will be used when storing and retrieving the image to/from cache.
    let identifier = "org.openhab.svgprocessor"

    // Convert input data/image to target image and return it.
    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        switch item {
        case let .image(image):
            os_log("already an image", log: .default, type: .info)
            return image
        case let .data(data):
            if let image = SVGKImage(data: data) {
                return image.uiImage
            } else {
                return nil
            }
        }
    }
}

private let openHABViewControllerMapViewCellReuseIdentifier = "OpenHABViewControllerMapViewCellReuseIdentifier"
private let openHABViewControllerImageViewCellReuseIdentifier = "OpenHABViewControllerImageViewCellReuseIdentifier"

class OpenHABViewController: UIViewController {
    var tracker: OpenHABTracker?
    var hamburgerButton: DynamicButton!
    private var selectedWidgetRow: Int = 0
    private var currentPageOperation: Alamofire.Request?
    private var commandOperation: Alamofire.Request?
    var pageUrl = ""
    var openHABRootUrl = ""
    var openHABUsername = ""
    var openHABPassword = ""
    var openHABAlwaysSendCreds = false
    var defaultSitemap = ""
    var idleOff = false
    var sitemaps: [OpenHABSitemap] = []
    var currentPage: OpenHABSitemapPage?
    var selectionPicker: UIPickerView?
    var pageNetworkStatus: NetworkReachabilityManager.NetworkReachabilityStatus?
    var pageNetworkStatusAvailable = false
    var toggle: Int = 0
    var deviceToken = ""
    var deviceId = ""
    var deviceName = ""
    var refreshControl: UIRefreshControl?
    var iconType: IconType = .png
    let search = UISearchController(searchResultsController: nil)
    var filteredPage: OpenHABSitemapPage?

    var relevantPage: OpenHABSitemapPage? {
        if isFiltering {
            return filteredPage
        } else {
            return currentPage
        }
    }

    // App wide data access
    // https://stackoverflow.com/questions/45832155/how-do-i-refactor-my-code-to-call-appdelegate-on-the-main-thread
    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

    // MARK: - Private instance methods

    var searchBarIsEmpty: Bool {
        // Returns true if the text is empty or nil
        search.searchBar.text?.isEmpty ?? true
    }

    var isFiltering: Bool {
        search.isActive && !searchBarIsEmpty
    }

    @IBOutlet private var widgetTableView: UITableView!

    // Here goes everything about view loading, appearing, disappearing, entering background and becoming active
    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("OpenHABViewController viewDidLoad", log: .default, type: .info)

        pageNetworkStatus = nil
        sitemaps = []
        widgetTableView.tableFooterView = UIView()
        NotificationCenter.default.addObserver(self, selector: #selector(OpenHABViewController.didEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(OpenHABViewController.didBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)

        registerTableViewCells()
        configureTableView()

        refreshControl = UIRefreshControl()

        refreshControl?.addTarget(self, action: #selector(OpenHABViewController.handleRefresh(_:)), for: .valueChanged)
        if let refreshControl = refreshControl {
            widgetTableView.refreshControl = refreshControl
        }

        let hamburgerButtonItem: UIBarButtonItem
        if #available(iOS 13.0, *) {
            let imageConfig = UIImage.SymbolConfiguration(textStyle: .largeTitle)
            let buttonImage = UIImage(systemName: "line.horizontal.3", withConfiguration: imageConfig)
            let button = UIButton(type: .custom)
            button.setImage(buttonImage, for: .normal)
            button.addTarget(self, action: #selector(OpenHABViewController.rightDrawerButtonPress(_:)), for: .touchUpInside)
            hamburgerButtonItem = UIBarButtonItem(customView: button)
            hamburgerButtonItem.customView?.heightAnchor.constraint(equalToConstant: 30).isActive = true
        } else {
            hamburgerButton = DynamicButton(frame: CGRect(x: 0, y: 0, width: 31, height: 31))
            hamburgerButton.setStyle(.hamburger, animated: true)
            hamburgerButton.addTarget(self, action: #selector(OpenHABViewController.rightDrawerButtonPress(_:)), for: .touchUpInside)
            hamburgerButton.strokeColor = view.tintColor
            hamburgerButtonItem = UIBarButtonItem(customView: hamburgerButton)
        }
        navigationItem.setRightBarButton(hamburgerButtonItem, animated: true)

        navigationController?.navigationBar.prefersLargeTitles = true

        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "Search openHAB items"
        definesPresentationContext = true

        setupSideMenu()

        #if DEBUG
        // setup accessibilityIdentifiers for UITest
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "HamburgerButton"
        widgetTableView.accessibilityIdentifier = "OpenHABViewControllerWidgetTableView"
        #endif
    }

    override func viewDidAppear(_ animated: Bool) {
        os_log("OpenHABViewController viewDidAppear", log: .viewCycle, type: .info)
        super.viewDidAppear(animated)

        // NOTE: workaround for https://github.com/openhab/openhab-ios/issues/420
        if navigationItem.searchController == nil {
            DispatchQueue.main.async {
                self.navigationItem.searchController = self.search
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        os_log("OpenHABViewController viewWillAppear", log: .viewCycle, type: .info)
        super.viewWillAppear(animated)
        // Load settings into local properties
        loadSettings()
        // Disable idle timeout if configured in settings
        if idleOff {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        doRegisterAps()
        // if pageUrl == "" it means we are the first opened OpenHABViewController
        if pageUrl == "" {
            // Set self as root view controller
            appData?.rootViewController = self
            NetworkConnection.shared.assignDelegates(serverDelegate: self, clientDelegate: self)
            // Add self as observer for APS registration
            NotificationCenter.default.addObserver(self, selector: #selector(OpenHABViewController.handleApsRegistration(_:)), name: NSNotification.Name("apsRegistered"), object: nil)
            if currentPage != nil {
                currentPage?.widgets = []
                widgetTableView.reloadData()
            }
            os_log("OpenHABViewController pageUrl is empty, this is first launch", log: .viewCycle, type: .info)
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            tracker = OpenHABTracker()
            tracker?.delegate = self
            tracker?.start()
        } else {
            if !pageNetworkStatusChanged() {
                os_log("OpenHABViewController pageUrl = %{PUBLIC}@", log: .notifications, type: .info, pageUrl)
                loadPage(false)
            } else {
                os_log("OpenHABViewController network status changed while I was not appearing", log: .viewCycle, type: .info)
                restart()
            }
        }
        ImageDownloader.default.authenticationChallengeResponder = self
    }

    override func viewWillDisappear(_ animated: Bool) {
        os_log("OpenHABViewController viewWillDisappear", log: .viewCycle, type: .info)
        if currentPageOperation != nil {
            currentPageOperation?.cancel()
            currentPageOperation = nil
        }
        super.viewWillDisappear(animated)

        // workaround for #309 (see: https://stackoverflow.com/questions/46301813/broken-uisearchbar-animation-embedded-in-navigationitem)
        if #available(iOS 13.0, *) {
            // do nothing
        } else {
            if animated, !search.isActive, !search.isEditing, navigationController.map({ $0.viewControllers.last != self }) ?? false,
                let searchBarSuperview = search.searchBar.superview,
                let searchBarHeightConstraint = searchBarSuperview.constraints.first(where: {
                    $0.firstAttribute == .height
                        && $0.secondItem == nil
                        && $0.secondAttribute == .notAnAttribute
                        && $0.constant > 0
                }) {
                UIView.performWithoutAnimation {
                    searchBarHeightConstraint.constant = 0
                    searchBarSuperview.superview?.layoutIfNeeded()
                }
            }
        }
    }

    @objc
    func didEnterBackground(_ notification: Notification?) {
        os_log("OpenHABViewController didEnterBackground", log: .viewCycle, type: .info)
        if currentPageOperation != nil {
            currentPageOperation?.cancel()
            currentPageOperation = nil
        }
        UIApplication.shared.isIdleTimerDisabled = false
    }

    @objc
    func didBecomeActive(_ notification: Notification?) {
        os_log("OpenHABViewController didBecomeActive", log: .viewCycle, type: .info)
        // re disable idle off timer
        if idleOff {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        if isViewLoaded, view.window != nil, !pageUrl.isEmpty {
            if !pageNetworkStatusChanged() {
                os_log("OpenHABViewController isViewLoaded, restarting network activity", log: .viewCycle, type: .info)
                loadPage(false)
            } else {
                os_log("OpenHABViewController network status changed while it was inactive", log: .viewCycle, type: .info)
                restart()
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        widgetTableView.reloadData()
    }

    fileprivate func setupSideMenu() {
        // Define the menus

        SideMenuManager.default.rightMenuNavigationController = storyboard!.instantiateViewController(withIdentifier: "RightMenuNavigationController") as? SideMenuNavigationController

        // Enable gestures. The left and/or right menus must be set up above for these to work.
        // Note that these continue to work on the Navigation Controller independent of the View Controller it displays!
        SideMenuManager.default.addPanGestureToPresent(toView: navigationController!.navigationBar)
        SideMenuManager.default.addScreenEdgePanGesturesToPresent(toView: navigationController!.view, forMenu: .right)

        let presentationStyle: SideMenuPresentationStyle = .viewSlideOutMenuIn
        presentationStyle.presentingEndAlpha = 1
        presentationStyle.onTopShadowOpacity = 0.5
        var settings = SideMenuSettings()
        settings.presentationStyle = presentationStyle
        settings.statusBarEndAlpha = 0

        SideMenuManager.default.rightMenuNavigationController?.settings = settings
    }

    func configureTableView() {
        widgetTableView.dataSource = self
        widgetTableView.delegate = self
    }

    func registerTableViewCells() {
        widgetTableView.register(MapViewTableViewCell.self, forCellReuseIdentifier: openHABViewControllerMapViewCellReuseIdentifier)
        widgetTableView.register(cellType: MapViewTableViewCell.self)
        widgetTableView.register(NewImageUITableViewCell.self, forCellReuseIdentifier: openHABViewControllerImageViewCellReuseIdentifier)
        widgetTableView.register(cellType: VideoUITableViewCell.self)
    }

    @objc
    func handleRefresh(_ refreshControl: UIRefreshControl?) {
        loadPage(false)
        widgetTableView.reloadData()
        widgetTableView.layoutIfNeeded()
    }

    @objc
    func handleApsRegistration(_ note: Notification?) {
        os_log("handleApsRegistration", log: .notifications, type: .info)
        let theData = note?.userInfo
        if theData != nil {
            deviceId = theData?["deviceId"] as? String ?? ""
            deviceToken = theData?["deviceToken"] as? String ?? ""
            deviceName = theData?["deviceName"] as? String ?? ""
            doRegisterAps()
        }
    }

    @objc
    func rightDrawerButtonPress(_ sender: Any?) {
        guard let menu = SideMenuManager.default.rightMenuNavigationController else { return }

        let drawer = menu.viewControllers.first as? OpenHABDrawerTableViewController
        drawer?.openHABRootUrl = openHABRootUrl
        drawer?.delegate = self
        drawer?.drawerTableType = .withStandardMenuEntries

        present(menu, animated: true)
    }

    func doRegisterAps() {
        let prefsURL = Preferences.remoteUrl
        if prefsURL.contains("openhab.org") {
            if !deviceId.isEmpty, !deviceToken.isEmpty, !deviceName.isEmpty {
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

    func restart() {
        if appData?.rootViewController == self {
            os_log("I am a rootViewController!", log: .viewCycle, type: .info)

        } else {
            appData?.rootViewController?.pageUrl = ""
            navigationController?.popToRootViewController(animated: true)
        }
    }

    func relevantWidget(indexPath: IndexPath) -> OpenHABWidget? {
        relevantPage?.widgets[indexPath.row]
    }

    private func updateWidgetTableView() {
        UIView.performWithoutAnimation {
            widgetTableView.beginUpdates()
            widgetTableView.endUpdates()
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        os_log("OpenHABViewController prepareForSegue %{PUBLIC}@", log: .viewCycle, type: .info, segue.identifier ?? "")

        switch segue.identifier {
        case "showSelectionView": os_log("Selection seague", log: .viewCycle, type: .info)
        case "showSelectSitemap":
            let dest = segue.destination as! OpenHABDrawerTableViewController
            dest.openHABRootUrl = openHABRootUrl
            dest.drawerTableType = .withoutStandardMenuEntries
            dest.delegate = self
        default: break
        }
    }

    // load our page and show it into UITableView
    func loadPage(_ longPolling: Bool) {
        if currentPageOperation != nil {
            currentPageOperation?.cancel()
            currentPageOperation = nil
        }

        if pageUrl == "" {
            return
        }
        os_log("pageUrl = %{PUBLIC}@", log: .remoteAccess, type: .info, pageUrl)

        // If this is the first request to the page make a bulk call to pageNetworkStatusChanged
        // to save current reachability status.
        if !longPolling {
            _ = pageNetworkStatusChanged()
        }

        currentPageOperation = NetworkConnection.page(pageUrl: pageUrl,
                                                      longPolling: longPolling,
                                                      openHABVersion: appData?.openHABVersion ?? 2) { [weak self] response in
                guard let self = self else { return }

                switch response.result {
                case .success:
                    os_log("Page loaded with success", log: .remoteAccess, type: .info)
                    let headers = response.response?.allHeaderFields

                    NetworkConnection.atmosphereTrackingId = headers?["X-Atmosphere-tracking-id"] as? String ?? ""
                    if !NetworkConnection.atmosphereTrackingId.isEmpty {
                        os_log("Found X-Atmosphere-tracking-id: %{PUBLIC}@", log: .remoteAccess, type: .info, NetworkConnection.atmosphereTrackingId)
                    }
                    var openHABSitemapPage: OpenHABSitemapPage?
                    if let data = response.result.value {
                        // If we are talking to openHAB 1.X, talk XML
                        if self.appData?.openHABVersion == 1 {
                            let str = String(decoding: data, as: UTF8.self)
                            os_log("%{PUBLIC}@", log: .remoteAccess, type: .info, str)

                            guard let doc = try? XMLDocument(data: data) else { return }
                            if let rootElement = doc.root, let name = rootElement.tag {
                                os_log("XML sitemap with root element: %{PUBLIC}@", log: .remoteAccess, type: .info, name)
                                if name == "page" {
                                    openHABSitemapPage = OpenHABSitemapPage(xml: rootElement)
                                }
                            }
                        } else {
                            // Newer versions talk JSON!
                            os_log("openHAB 2", log: .remoteAccess, type: .info)
                            do {
                                // Self-executing closure
                                // Inspired by https://www.swiftbysundell.com/posts/inline-types-and-functions-in-swift
                                openHABSitemapPage = try {
                                    let sitemapPageCodingData = try data.decoded(as: OpenHABSitemapPage.CodingData.self)
                                    return sitemapPageCodingData.openHABSitemapPage
                                }()
                            } catch {
                                os_log("Should not throw %{PUBLIC}@", log: .remoteAccess, type: .error, error.localizedDescription)
                            }
                        }
                    }
                    self.currentPage = openHABSitemapPage
                    if self.isFiltering {
                        self.filterContentForSearchText(self.search.searchBar.text)
                    }

                    self.currentPage?.sendCommand = { [weak self] item, command in
                        self?.sendCommand(item, commandToSend: command)
                    }
                    self.widgetTableView.reloadData()
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    self.refreshControl?.endRefreshing()
                    self.navigationItem.title = self.currentPage?.title.components(separatedBy: "[")[0]
                    self.loadPage(true)
                case let .failure(error):
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    os_log("On LoadPage %{PUBLIC}@ code: %d ", log: .remoteAccess, type: .error, error.localizedDescription, response.response?.statusCode ?? 0)

                    NetworkConnection.atmosphereTrackingId = ""
                    if (error as NSError?)?.code == -1001, longPolling {
                        os_log("Timeout, restarting requests", log: .remoteAccess, type: .error)
                        self.loadPage(false)
                    } else if (error as NSError?)?.code == -999 {
                        os_log("Request was cancelled", log: .remoteAccess, type: .error)
                    } else {
                        // Error
                        DispatchQueue.main.async {
                            if (error as NSError?)?.code == -1012 {
                                var config = SwiftMessages.Config()
                                config.duration = .seconds(seconds: 5)
                                config.presentationStyle = .bottom

                                SwiftMessages.show(config: config) {
                                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                                    let view = MessageView.viewFromNib(layout: .cardView)
                                    // ... configure the view
                                    view.configureTheme(.error)
                                    view.configureContent(title: "Error", body: "SSL Certificate Error")
                                    view.button?.setTitle("Dismiss", for: .normal)
                                    view.buttonTapHandler = { _ in SwiftMessages.hide() }
                                    return view
                                }
                            } else {
                                var config = SwiftMessages.Config()
                                config.duration = .seconds(seconds: 5)
                                config.presentationStyle = .bottom

                                SwiftMessages.show(config: config) {
                                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                                    let view = MessageView.viewFromNib(layout: .cardView)
                                    // ... configure the view
                                    view.configureTheme(.error)
                                    view.configureContent(title: "Error", body: error.localizedDescription)
                                    view.button?.setTitle("Dismiss", for: .normal)
                                    view.buttonTapHandler = { _ in SwiftMessages.hide() }
                                    return view
                                }
                            }
                        }
                    }
                }
        }
        currentPageOperation?.resume()

        os_log("OpenHABViewController request sent", log: .remoteAccess, type: .error)
    }

    // Select sitemap
    func selectSitemap() {
        NetworkConnection.sitemaps(openHABRootUrl: openHABRootUrl) { response in
            switch response.result {
            case .success:
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                self.sitemaps = deriveSitemaps(response.result.value, version: self.appData?.openHABVersion)
                switch self.sitemaps.count {
                case 2...:
                    if !self.defaultSitemap.isEmpty {
                        if let sitemapToOpen = self.sitemap(byName: self.defaultSitemap) {
                            if self.currentPage?.pageId != sitemapToOpen.name {
                                self.currentPage?.widgets.removeAll() // NOTE: remove all widgets to ensure cells get invalidated
                            }
                            self.pageUrl = sitemapToOpen.homepageLink
                            self.loadPage(false)
                        } else {
                            self.performSegue(withIdentifier: "showSelectSitemap", sender: self)
                        }
                    } else {
                        self.performSegue(withIdentifier: "showSelectSitemap", sender: self)
                    }
                case 1:
                    self.pageUrl = self.sitemaps[0].homepageLink
                    self.loadPage(false)
                case ...0:
                    var config = SwiftMessages.Config()
                    config.duration = .seconds(seconds: 5)
                    config.presentationStyle = .bottom

                    SwiftMessages.show(config: config) {
                        UIApplication.shared.isNetworkActivityIndicatorVisible = false
                        let view = MessageView.viewFromNib(layout: .cardView)
                        // ... configure the view
                        view.configureTheme(.error)
                        view.configureContent(title: "Error", body: "openHAB returned empty sitemap list")
                        view.button?.setTitle("Dismiss", for: .normal)
                        view.buttonTapHandler = { _ in SwiftMessages.hide() }
                        return view
                    }
                default: break
                }
                self.widgetTableView.reloadData()
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            case let .failure(error):
                os_log("%{PUBLIC}@ %d", log: .default, type: .error, error.localizedDescription, response.response?.statusCode ?? 0)
                DispatchQueue.main.async {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    // Error
                    if (error as NSError?)?.code == -1012 {
                        var config = SwiftMessages.Config()
                        config.duration = .seconds(seconds: 5)
                        config.presentationStyle = .bottom

                        SwiftMessages.show(config: config) {
                            UIApplication.shared.isNetworkActivityIndicatorVisible = false
                            let view = MessageView.viewFromNib(layout: .cardView)
                            view.configureTheme(.error)
                            view.configureContent(title: "Error", body: "SSL Certificate Error")
                            view.button?.setTitle("Dismiss", for: .normal)
                            view.buttonTapHandler = { _ in SwiftMessages.hide() }
                            return view
                        }
                    } else {
                        var config = SwiftMessages.Config()
                        config.duration = .seconds(seconds: 5)
                        config.presentationStyle = .bottom

                        SwiftMessages.show(config: config) {
                            UIApplication.shared.isNetworkActivityIndicatorVisible = false
                            let view = MessageView.viewFromNib(layout: .cardView)
                            view.configureTheme(.error)
                            view.configureContent(title: "Error", body: error.localizedDescription)
                            view.button?.setTitle("Dismiss", for: .normal)
                            view.buttonTapHandler = { _ in SwiftMessages.hide() }
                            return view
                        }
                    }
                }
                UIApplication.shared.isNetworkActivityIndicatorVisible = true
            }
        }
    }

    // load app settings
    func loadSettings() {
        openHABUsername = Preferences.username
        openHABPassword = Preferences.password
        openHABAlwaysSendCreds = Preferences.alwaysSendCreds
        defaultSitemap = Preferences.defaultSitemap
        idleOff = Preferences.idleOff
        let rawIconType = Preferences.iconType
        iconType = IconType(rawValue: rawIconType) ?? .png

        appData?.openHABUsername = openHABUsername
        appData?.openHABPassword = openHABPassword
        appData?.openHABAlwaysSendCreds = openHABAlwaysSendCreds

        #if DEBUG
        // always use demo sitemap for UITest
        if ProcessInfo.processInfo.environment["UITest"] != nil {
            defaultSitemap = "demo"
            iconType = .png
        }
        #endif
    }

    // Find and return sitemap by it's name if any
    func sitemap(byName sitemapName: String?) -> OpenHABSitemap? {
        for sitemap in sitemaps where sitemap.name == sitemapName {
            return sitemap
        }
        return nil
    }

    func pageNetworkStatusChanged() -> Bool {
        os_log("OpenHABViewController pageNetworkStatusChange", log: .remoteAccess, type: .info)
        if !pageUrl.isEmpty {
            let pageReachability = NetworkReachabilityManager(host: pageUrl)
            if !pageNetworkStatusAvailable {
                pageNetworkStatus = pageReachability?.networkReachabilityStatus
                pageNetworkStatusAvailable = true
                return false
            } else {
                if pageNetworkStatus == pageReachability?.networkReachabilityStatus {
                    return false
                } else {
                    pageNetworkStatus = pageReachability?.networkReachabilityStatus
                    return true
                }
            }
        }
        return false
    }

    func filterContentForSearchText(_ searchText: String?, scope: String = "All") {
        guard let searchText = searchText else { return }

        filteredPage = currentPage?.filter {
            $0.label.lowercased().contains(searchText.lowercased()) && $0.type != .frame
        }
        filteredPage?.sendCommand = { [weak self] item, command in
            self?.sendCommand(item, commandToSend: command)
        }
        widgetTableView.reloadData()
    }

    func sendCommand(_ item: OpenHABItem?, commandToSend command: String?) {
        if commandOperation != nil {
            commandOperation?.cancel()
            commandOperation = nil
        }
        if let item = item, let command = command {
            commandOperation = NetworkConnection.sendCommand(item: item, commandToSend: command)
            commandOperation?.resume()
        }
    }

    func sideMenuWillDisappear(menu: SideMenuNavigationController, animated: Bool) {
        if #available(iOS 13.0, *) {
            let imageConfig = UIImage.SymbolConfiguration(textStyle: .largeTitle)
            let buttonImage = UIImage(systemName: "line.horizontal.3", withConfiguration: imageConfig)
            let button = UIButton(type: .custom)
            button.setImage(buttonImage, for: .normal)
            button.addTarget(self, action: #selector(OpenHABViewController.rightDrawerButtonPress(_:)), for: .touchUpInside)
            let hamburgerButtonItem = UIBarButtonItem(customView: button)
            hamburgerButtonItem.customView?.heightAnchor.constraint(equalToConstant: 30).isActive = true
            navigationItem.setRightBarButton(hamburgerButtonItem, animated: true)
        } else {
            hamburgerButton.setStyle(.hamburger, animated: animated)
        }
    }
}

// MARK: - OpenHABTrackerDelegate

extension OpenHABViewController: OpenHABTrackerDelegate {
    func openHABTracked(_ openHABUrl: URL?) {
        os_log("OpenHABViewController openHAB URL =  %{PUBLIC}@", log: .remoteAccess, type: .error, "\(openHABUrl!)")

        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }
        if let openHABUrl = openHABUrl {
            openHABRootUrl = openHABUrl.absoluteString
        } else {
            openHABRootUrl = ""
        }
        appData?.openHABRootUrl = openHABRootUrl

        NetworkConnection.tracker(openHABRootUrl: openHABRootUrl) { response in
            switch response.result {
            case .success:
                os_log("This is an openHAB 2.X", log: .remoteAccess, type: .info)

                self.appData?.openHABVersion = 2

                DispatchQueue.main.async {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                }

                if let data = response.result.value {
                    do {
                        self.appData?.serverProperties = try data.decoded(as: OpenHABServerProperties.self)
                    } catch {
                        os_log("Could not decode JSON response", log: .notifications, type: .error, error.localizedDescription)
                    }
                }

                self.selectSitemap()
            case let .failure(error):
                os_log("This is an openHAB 1.X", log: .remoteAccess, type: .info)
                self.appData?.openHABVersion = 1

                DispatchQueue.main.async {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                }
                os_log("On Tracking %{PUBLIC}@ %d", log: .remoteAccess, type: .error, error.localizedDescription, response.response?.statusCode ?? 0)
                self.selectSitemap()
            }
        }
    }

    func openHABTrackingProgress(_ message: String?) {
        os_log("OpenHABViewController %{PUBLIC}@", log: .viewCycle, type: .info, message ?? "")
        var config = SwiftMessages.Config()
        config.duration = .seconds(seconds: 1.5)
        config.presentationStyle = .bottom

        SwiftMessages.show(config: config) {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            let view = MessageView.viewFromNib(layout: .cardView)
            view.configureTheme(.info)
            view.configureContent(title: "Connecting", body: message ?? "")
            view.button?.setTitle("Dismiss", for: .normal)
            view.buttonTapHandler = { _ in SwiftMessages.hide() }
            return view
        }
    }

    func openHABTrackingError(_ error: Error) {
        os_log("OpenHABViewController discovery error", log: .viewCycle, type: .info)
        var config = SwiftMessages.Config()
        config.duration = .seconds(seconds: 60)
        config.presentationStyle = .bottom

        SwiftMessages.show(config: config) {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            let view = MessageView.viewFromNib(layout: .cardView)
            // ... configure the view
            view.configureTheme(.error)
            view.configureContent(title: "Error", body: error.localizedDescription)
            view.button?.setTitle("Dismiss", for: .normal)
            view.buttonTapHandler = { _ in SwiftMessages.hide() }
            return view
        }
    }
}

// MARK: - OpenHABSelectionTableViewControllerDelegate

extension OpenHABViewController: OpenHABSelectionTableViewControllerDelegate {
    // send command on selected selection widget mapping
    func didSelectWidgetMapping(_ selectedMappingIndex: Int) {
        let selectedWidget: OpenHABWidget? = relevantPage?.widgets[selectedWidgetRow]
        let selectedMapping: OpenHABWidgetMapping? = selectedWidget?.mappingsOrItemOptions[selectedMappingIndex]
        sendCommand(selectedWidget?.item, commandToSend: selectedMapping?.command)
    }
}

// MARK: - UISearchResultsUpdating

extension OpenHABViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchController.searchBar.text)
    }
}

// MARK: - ColorPickerUITableViewCellDelegate

extension OpenHABViewController: ColorPickerUITableViewCellDelegate {
    func didPressColorButton(_ cell: ColorPickerUITableViewCell?) {
        let colorPickerViewController = storyboard?.instantiateViewController(withIdentifier: "ColorPickerViewController") as? ColorPickerViewController
        if let cell = cell {
            let widget = relevantPage?.widgets[widgetTableView.indexPath(for: cell)?.row ?? 0]
            colorPickerViewController?.title = widget?.labelText
            colorPickerViewController?.widget = widget
        }
        if let colorPickerViewController = colorPickerViewController {
            navigationController?.pushViewController(colorPickerViewController, animated: true)
        }
    }
}

// MARK: - ServerCertificateManagerDelegate

extension OpenHABViewController: ServerCertificateManagerDelegate {
    // delegate should ask user for a decision on what to do with invalid certificate
    func evaluateServerTrust(_ policy: ServerCertificateManager?, summary certificateSummary: String?, forDomain domain: String?) {
        DispatchQueue.main.async {
            let alertView = UIAlertController(title: "SSL Certificate Warning", message: "SSL Certificate presented by \(certificateSummary ?? "") for \(domain ?? "") is invalid. Do you want to proceed?", preferredStyle: .alert)
            alertView.addAction(UIAlertAction(title: "Abort", style: .default) { _ in policy?.evaluateResult = .deny })
            alertView.addAction(UIAlertAction(title: "Once", style: .default) { _ in policy?.evaluateResult = .permitOnce })
            alertView.addAction(UIAlertAction(title: "Always", style: .default) { _ in policy?.evaluateResult = .permitAlways })
            self.present(alertView, animated: true) {}
        }
    }

    // certificate received from openHAB doesn't match our record, ask user for a decision
    func evaluateCertificateMismatch(_ policy: ServerCertificateManager?, summary certificateSummary: String?, forDomain domain: String?) {
        DispatchQueue.main.async {
            let alertView = UIAlertController(title: "SSL Certificate Warning", message: "SSL Certificate presented by \(certificateSummary ?? "") for \(domain ?? "") doesn't match the record. Do you want to proceed?", preferredStyle: .alert)
            alertView.addAction(UIAlertAction(title: "Abort", style: .default) { _ in policy?.evaluateResult = .deny })
            alertView.addAction(UIAlertAction(title: "Once", style: .default) { _ in policy?.evaluateResult = .permitOnce })
            alertView.addAction(UIAlertAction(title: "Always", style: .default) { _ in policy?.evaluateResult = .permitAlways })
            self.present(alertView, animated: true) {}
        }
    }

    func acceptedServerCertificatesChanged(_ policy: ServerCertificateManager?) {
        // User's decision about trusting server certificates has changed.  Send updates to the paired watch.
        WatchMessageService.singleton.syncPreferencesToWatch()
    }
}

// MARK: - ClientCertificateManagerDelegate

extension OpenHABViewController: ClientCertificateManagerDelegate {
    // delegate should ask user for a decision on whether to import the client certificate into the keychain
    func askForClientCertificateImport(_ clientCertificateManager: ClientCertificateManager?) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: "Client Certificate Import", message: "Import client certificate into the keychain?", preferredStyle: .alert)
            let okay = UIAlertAction(title: "Okay", style: .default) { (_: UIAlertAction) in
                clientCertificateManager!.clientCertificateAccepted(password: nil)
            }
            let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (_: UIAlertAction) in
                clientCertificateManager!.clientCertificateRejected()
            }
            alertController.addAction(okay)
            alertController.addAction(cancel)
            self.present(alertController, animated: true, completion: nil)
        }
    }

    // delegate should ask user for the export password used to decode the PKCS#12
    func askForCertificatePassword(_ clientCertificateManager: ClientCertificateManager?) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: "Client Certificate Import", message: "Password required for import.", preferredStyle: .alert)
            let okay = UIAlertAction(title: "Okay", style: .default) { (_: UIAlertAction) in
                let txtField = alertController.textFields?.first
                let password = txtField?.text
                clientCertificateManager!.clientCertificateAccepted(password: password)
            }
            let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (_: UIAlertAction) in
                clientCertificateManager!.clientCertificateRejected()
            }
            alertController.addTextField { textField in
                textField.placeholder = "Password"
                textField.isSecureTextEntry = true
            }
            alertController.addAction(okay)
            alertController.addAction(cancel)
            self.present(alertController, animated: true, completion: nil)
        }
    }

    // delegate should alert the user that an error occured importing the certificate
    func alertClientCertificateError(_ clientCertificateManager: ClientCertificateManager?, errMsg: String) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: "Client Certificate Import", message: errMsg, preferredStyle: .alert)
            let okay = UIAlertAction(title: "Okay", style: .default)
            alertController.addAction(okay)
            self.present(alertController, animated: true, completion: nil)
        }
    }
}

// MARK: - ModalHandler

extension OpenHABViewController: ModalHandler {
    func modalDismissed(to: TargetController) {
        switch to {
        case .root:
            navigationController?.popToRootViewController(animated: true)
            defaultSitemap = Preferences.defaultSitemap
            selectSitemap()
        case .settings:
            if let newViewController = storyboard?.instantiateViewController(withIdentifier: "OpenHABSettingsViewController") as? OpenHABSettingsViewController {
                navigationController?.pushViewController(newViewController, animated: true)
            }
        case .notifications:
            if navigationController?.visibleViewController is OpenHABNotificationsViewController {
                os_log("Notifications are already open", log: .notifications, type: .info)
            } else {
                if let newViewController = storyboard?.instantiateViewController(withIdentifier: "OpenHABNotificationsViewController") as? OpenHABNotificationsViewController {
                    navigationController?.pushViewController(newViewController, animated: true)
                }
            }
        case .habpanel:
            if let newViewController = storyboard?.instantiateViewController(withIdentifier: "HABPanelViewController") as? HABPanelViewController {
                navigationController?.pushViewController(newViewController, animated: true)
            }
        }
    }
}

// MARK: - UISideMenuNavigationControllerDelegate

extension OpenHABViewController: SideMenuNavigationControllerDelegate {
    func sideMenuWillAppear(menu: SideMenuNavigationController, animated: Bool) {
        if #available(iOS 13.0, *) {
            let imageConfig = UIImage.SymbolConfiguration(textStyle: .largeTitle)
            let buttonImage = UIImage(systemName: "arrow.right", withConfiguration: imageConfig)
            let button = UIButton(type: .custom)
            button.setImage(buttonImage, for: .normal)
            button.addTarget(self, action: #selector(OpenHABViewController.rightDrawerButtonPress(_:)), for: .touchUpInside)
            let hamburgerButtonItem = UIBarButtonItem(customView: button)
            hamburgerButtonItem.customView?.heightAnchor.constraint(equalToConstant: 30).isActive = true
            navigationItem.setRightBarButton(hamburgerButtonItem, animated: true)
        } else {
            hamburgerButton.setStyle(.arrowRight, animated: animated)
        }

        guard let drawer = menu.viewControllers.first as? OpenHABDrawerTableViewController,
            drawer.delegate == nil || drawer.openHABRootUrl.isEmpty
        else {
            return
        }
        drawer.openHABRootUrl = openHABRootUrl
        drawer.delegate = self
        drawer.drawerTableType = .withStandardMenuEntries
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension OpenHABViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if currentPage != nil {
            if isFiltering {
                return filteredPage?.widgets.count ?? 0
            }
            return currentPage?.widgets.count ?? 0
        } else {
            return 0
        }
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        44.0
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let widget: OpenHABWidget? = relevantPage?.widgets[indexPath.row]
        switch widget?.type {
        case .frame:
            return widget?.label.count ?? 0 > 0 ? 35.0 : 0
        case .image, .chart, .video:
            return UITableView.automaticDimension
        case .webview, .mapview:
            if let height = widget?.height {
                // calculate webview/mapview height and return it
                let heightValue = height * 44
                os_log("Webview/Mapview height would be %g", log: .viewCycle, type: .info, heightValue)
                return CGFloat(heightValue)
            } else {
                // return default height for webview/mapview as 8 rows
                return 44.0 * 8
            }
        default: return 44.0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let widget: OpenHABWidget? = relevantWidget(indexPath: indexPath)

        let cell: UITableViewCell

        switch widget?.type {
        case .frame:
            cell = tableView.dequeueReusableCell(for: indexPath) as FrameUITableViewCell
        case .switchWidget:
            // Reflecting the discussion held in https://github.com/openhab/openhab-core/issues/952
            if !(widget?.mappings ?? []).isEmpty {
                cell = tableView.dequeueReusableCell(for: indexPath) as SegmentedUITableViewCell
            } else if widget?.item?.isOfTypeOrGroupType(.switchItem) ?? false {
                cell = tableView.dequeueReusableCell(for: indexPath) as SwitchUITableViewCell
            } else if widget?.item?.isOfTypeOrGroupType(.rollershutter) ?? false {
                cell = tableView.dequeueReusableCell(for: indexPath) as RollershutterUITableViewCell
            } else if !(widget?.mappingsOrItemOptions ?? []).isEmpty {
                cell = tableView.dequeueReusableCell(for: indexPath) as SegmentedUITableViewCell
            } else {
                cell = tableView.dequeueReusableCell(for: indexPath) as SwitchUITableViewCell
            }
        case .setpoint:
            cell = tableView.dequeueReusableCell(for: indexPath) as SetpointUITableViewCell
        case .slider:
            cell = tableView.dequeueReusableCell(for: indexPath) as SliderUITableViewCell
        case .selection:
            cell = tableView.dequeueReusableCell(for: indexPath) as SelectionUITableViewCell
        case .colorpicker:
            cell = tableView.dequeueReusableCell(for: indexPath) as ColorPickerUITableViewCell
            (cell as? ColorPickerUITableViewCell)?.delegate = self
        case .image, .chart:
            cell = tableView.dequeueReusableCell(withIdentifier: openHABViewControllerImageViewCellReuseIdentifier, for: indexPath) as! NewImageUITableViewCell
            (cell as? NewImageUITableViewCell)?.didLoad = { [weak self] in
                self?.updateWidgetTableView()
            }
        case .video:
            cell = tableView.dequeueReusableCell(withIdentifier: "VideoUITableViewCell", for: indexPath) as! VideoUITableViewCell
            (cell as? VideoUITableViewCell)?.didLoad = { [weak self] in
                self?.updateWidgetTableView()
            }
        case .webview:
            cell = tableView.dequeueReusableCell(for: indexPath) as WebUITableViewCell
        case .mapview:
            cell = (tableView.dequeueReusableCell(withIdentifier: openHABViewControllerMapViewCellReuseIdentifier) as? MapViewTableViewCell)!
        case .group, .text:
            cell = tableView.dequeueReusableCell(for: indexPath) as GenericUITableViewCell
        default:
            cell = tableView.dequeueReusableCell(for: indexPath) as GenericUITableViewCell
        }

        // No icon is needed for image, video, frame and web widgets
        if widget?.icon != nil, !((cell is NewImageUITableViewCell) || (cell is VideoUITableViewCell) || (cell is FrameUITableViewCell) || (cell is WebUITableViewCell)) {
            if let urlc = Endpoint.icon(rootUrl: openHABRootUrl,
                                        version: appData?.openHABVersion ?? 2,
                                        icon: widget?.icon,
                                        state: widget?.iconState() ?? "",
                                        iconType: iconType).url {
                var imageRequest = URLRequest(url: urlc)
                imageRequest.timeoutInterval = 10.0

                let reportOnResults: ((Swift.Result<RetrieveImageResult, KingfisherError>) -> Void)? = {
                    result in
                    switch result {
                    case let .success(value):
                        os_log("Task done for: %{PUBLIC}@", log: .viewCycle, type: .info, value.source.url?.absoluteString ?? "")
                    case let .failure(error):
                        os_log("Job failed: %{PUBLIC}@", log: .viewCycle, type: .info, error.localizedDescription)
                    }
                }

                switch iconType {
                case .png:
                    cell.imageView?.kf.setImage(with: ImageResource(downloadURL: urlc, cacheKey: urlc.path + (urlc.query ?? "")),
                                                placeholder: UIImage(named: "blankicon.png"),
                                                completionHandler: reportOnResults)
                case .svg:
                    cell.imageView?.kf.setImage(with: ImageResource(downloadURL: urlc, cacheKey: urlc.path + (urlc.query ?? "")),
                                                placeholder: UIImage(named: "blankicon.png"),
                                                options: [.processor(SVGProcessor())],
                                                completionHandler: reportOnResults)
                }
            }
        }

        if cell is FrameUITableViewCell {
            cell.backgroundColor = .ohSystemGroupedBackground
        } else {
            cell.backgroundColor = .ohSecondarySystemGroupedBackground
        }

        if let cell = cell as? GenericUITableViewCell {
            cell.widget = widget
            cell.displayWidget()
        }

        // Check if this is not the last row in the widgets list
        if indexPath.row < (relevantPage?.widgets.count ?? 1) - 1 {
            let nextWidget: OpenHABWidget? = relevantPage?.widgets[indexPath.row + 1]
            if let type = nextWidget?.type, type.isAny(of: .frame, .image, .video, .webview, .chart) {
                cell.separatorInset = UIEdgeInsets.zero
            } else if !(widget?.type == .frame) {
                cell.separatorInset = UIEdgeInsets(top: 0, left: 60, bottom: 0, right: 0)
            }
        }

        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Prevent the cell from inheriting the Table View's margin settings
        cell.preservesSuperviewLayoutMargins = false

        // Explictly set your cell's layout margins
        cell.layoutMargins = .zero

        (cell as? VideoUITableViewCell)?.play()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let widget: OpenHABWidget? = relevantWidget(indexPath: indexPath)
        if widget?.linkedPage != nil {
            if let link = widget?.linkedPage?.link {
                os_log("Selected %{PUBLIC}@", log: .viewCycle, type: .info, link)
            }
            selectedWidgetRow = indexPath.row
            let newViewController = (storyboard?.instantiateViewController(withIdentifier: "OpenHABPageViewController") as? OpenHABViewController)!
            newViewController.title = widget?.linkedPage?.title.components(separatedBy: "[")[0]
            newViewController.pageUrl = widget?.linkedPage?.link ?? ""
            newViewController.openHABRootUrl = openHABRootUrl
            navigationController?.pushViewController(newViewController, animated: true)
        } else if widget?.type == .selection {
            os_log("Selected selection widget", log: .viewCycle, type: .info)

            selectedWidgetRow = indexPath.row
            let selectionViewController = (storyboard?.instantiateViewController(withIdentifier: "OpenHABSelectionTableViewController") as? OpenHABSelectionTableViewController)!
            let selectedWidget: OpenHABWidget? = relevantWidget(indexPath: indexPath)
            selectionViewController.title = selectedWidget?.labelText
            selectionViewController.mappings = selectedWidget?.mappingsOrItemOptions ?? []
            selectionViewController.delegate = self
            selectionViewController.selectionItem = selectedWidget?.item
            navigationController?.pushViewController(selectionViewController, animated: true)
        }
        if let index = widgetTableView.indexPathForSelectedRow {
            widgetTableView.deselectRow(at: index, animated: false)
        }
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? GenericCellCacheProtocol {
            // invalidate cache only if the cell is not visible or the datasource is empty (eg. sitemap change)
            if tableView.indexPathsForVisibleRows == nil || !tableView.indexPathsForVisibleRows!.contains(indexPath) || currentPage == nil || currentPage!.widgets.isEmpty {
                cell.invalidateCache()
            }
        }
    }

    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        if let cell = tableView.cellForRow(at: indexPath) as? GenericUITableViewCell, cell.widget.type == .text, let text = cell.widget?.labelValue ?? cell.widget?.labelText, !text.isEmpty {
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
                let copy = UIAction(title: "Copy item label", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                    UIPasteboard.general.string = text
                }

                return UIMenu(title: "", children: [copy])
            }
        }

        return nil
    }
}

// MARK: Kingfisher authentication with NSURLCredential

extension OpenHABViewController: AuthenticationChallengeResponsable {
    // sessionDelegate.onReceiveSessionTaskChallenge
    func downloader(_ downloader: ImageDownloader,
                    task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let (disposition, credential) = onReceiveSessionTaskChallenge(URLSession(configuration: .default), task, challenge)
        completionHandler(disposition, credential)
    }

    // sessionDelegate.onReceiveSessionChallenge
    func downloader(_ downloader: ImageDownloader,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let (disposition, credential) = onReceiveSessionChallenge(URLSession(configuration: .default), challenge)
        completionHandler(disposition, credential)
    }
}
