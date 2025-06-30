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

import AVFoundation
import AVKit
import Combine
import Foundation
import Kingfisher
import OpenAPIRuntime
import OpenAPIURLSession
import OpenHABCore
import os.log
import SafariServices
import SFSafeSymbols
import SwiftMessages
import SwiftUI
import UIKit

class OpenHABSitemapViewController: OpenHABViewController, UISearchControllerDelegate {
    var pageUrl = ""
    private var iconType: IconType = .png
    private var openHABRootUrl = ""

    private var activeConnectionInfo: ConnectionInfo?

    private var defaultSitemap = ""
    private var pageId = ""
    private var idleOff = false
    private var sitemaps: [OpenHABSitemap] = []
    private var currentPage: OpenHABPage?
    private var pageNetworkStatus: NetworkStatus?
    private var pageNetworkStatusAvailable = false
    private var refreshControl: UIRefreshControl?
    private var filteredPage: OpenHABPage?
    private let searchController = UISearchController(searchResultsController: nil)
    private var isUserInteracting = false
    private var isWaitingToReload = false
    // Properties in your view controller:

    private var pageHandlingTask: Task<Void, Never>?

    private var pageLoader: PageLoader?

    private let logger = Logger(subsystem: "org.openhab.app", category: "OpenHABSitemapViewController")

    var relevantPage: OpenHABPage? {
        if isFiltering {
            filteredPage
        } else {
            currentPage
        }
    }

    var sitemapViewController: OpenHABSitemapViewController?

    // MARK: - Private instance methods

    var searchBarIsEmpty: Bool {
        // Returns true if the text is empty or nil
        searchController.searchBar.text?.isEmpty ?? true
    }

    var isFiltering: Bool {
        searchController.isActive && !searchBarIsEmpty
    }

    private var openAPIService: OpenAPIService?

    @IBOutlet private var widgetTableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        logger.info("OpenHABSitemapViewController viewDidLoad")

        registerTableViewCells()
        configureTableView()
        widgetTableView.tableFooterView = UIView()

        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(handleRefresh(_:)), for: .valueChanged)
        widgetTableView.refreshControl = refreshControl

        // Setup search controller
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.delegate = self
        searchController.delegate = self
        searchController.searchBar.placeholder = NSLocalizedString("search_items", comment: "")
        definesPresentationContext = true

        // Assign to navigation item (must be in navigation stack)
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        // Setup active connection
        guard let config = activeConnectionInfo?.configuration else { return }
        do {
            openAPIService = try OpenAPIService(connectionConfiguration: config)
        } catch {
            logger.error("Failed to create OpenAPIService: \(error.localizedDescription)")
        }

        if let service = openAPIService {
            pageLoader = PageLoader(service: service, pageId: "", defaultSitemap: "")
        }

        #if DEBUG
        widgetTableView.accessibilityIdentifier = "OpenHABSitemapViewControllerWidgetTableView"
        #endif
    }

    override func viewDidAppear(_ animated: Bool) {
        logger.info("OpenHABSitemapViewController viewDidAppear")
        super.viewDidAppear(animated)

        if parent?.navigationItem.searchController !== searchController {
            parent?.navigationItem.searchController = searchController
            parent?.navigationItem.hidesSearchBarWhenScrolling = true
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        logger.info("OpenHABSitemapViewController viewWillAppear")
        super.viewWillAppear(animated)

        navigationController?.navigationBar.prefersLargeTitles = true

        // Load settings into local properties
        loadSettings()
        // Disable idle timeout if configured in settings
        if idleOff {
            UIApplication.shared.isIdleTimerDisabled = true
        }

        // if pageUrl is empty, it means we are the first opened OpenHABSitemapViewController
        if pageUrl.isEmpty {
            sitemapViewController = self
//        if navigationController?.viewControllers.first == self {
            // This is the first sitemap opened
            if currentPage != nil {
                currentPage?.widgets = []
                widgetTableView.reloadData()
            }
            logger.info("OpenHABSitemapViewController pageUrl is empty, this is first launch")
        } else {
            if !pageNetworkStatusChanged() || !pageId.isEmpty {
                // swiftformat:disable:next redundantSelf
                logger.info("OpenHABSitemapViewController pageUrl \(self.pageUrl)")
                startPageHandling()
            } else {
                logger.info("OpenHABSitemapViewController network status changed while it was not appearing")
                restart()
            }
        }

        startTrackNetworkStatus()
        startWatchingActiveServer()

        ImageDownloader.default.authenticationChallengeResponder = self
    }

    override func viewWillDisappear(_ animated: Bool) {
        logger.info("OpenHABSitemapViewController viewWillDisappear")

        trackerCancellables.removeAll()
        stopAllTasks()

        super.viewWillDisappear(animated)

        if #unavailable(iOS 13.0) {
            if animated, !searchController.isActive, !searchController.isEditing, navigationController.map({ $0.viewControllers.last != self }) ?? false,
               let searchBarSuperview = searchController.searchBar.superview,
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
        parent?.navigationItem.searchController = nil
    }

    @objc
    override func didEnterBackground(_ notification: Notification?) {
        super.didEnterBackground(notification)
        logger.info("OpenHABSitemapViewController didEnterBackground")
    }

    @objc
    override func didBecomeActive(_ notification: Notification?) {
        super.didBecomeActive(notification)
        logger.info("OpenHABSitemapViewController didBecomeActive")
        if isViewLoaded, view.window != nil, !pageUrl.isEmpty {
            if !pageNetworkStatusChanged() {
                logger.info("OpenHABSitemapViewController isViewLoaded, restarting network activity")
                startPageHandling()
            } else {
                logger.info("OpenHABSitemapViewController network status changed while it was inactive")
                restart()
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        widgetTableView.reloadData()
    }

    private func startTrackNetworkStatus() {
        let task = Task {
            for await status in NetworkTracker.shared.$status.values {
                logger.info("OpenHABViewController tracker status \(status.rawValue)")
                await MainActor.run {
                    switch status {
                    case .connecting:
                        self.showPopupMessage(seconds: 1.5, title: NSLocalizedString("connecting", comment: ""), message: "", theme: .info)
                    case .notConnected:
                        logger.info("Tracking error")
//                        self.showPopupMessage(seconds: 60, title: NSLocalizedString("error", comment: ""), message: NSLocalizedString("network_not_available", comment: ""), theme: .error)
                    case .connected, .allConnected, .someConnected:
                        self.hidePopupMessages()
                    }
                }
            }
        }
        activeTasks.insert(task)
    }

    func startWatchingActiveServer() {
        let task = Task {
            for await activeConnection in NetworkTracker.shared.$activeConnection.values {
                if let activeConnection {
                    await MainActor.run {
                        logger.info("OpenHABSitemapViewController tracker URL \(activeConnection.configuration.url)")
                        self.openHABRootUrl = activeConnection.configuration.url
                        self.activeConnectionInfo = activeConnection
                        self.selectSitemap()
                    }
                    break
                }
            }
        }
        activeTasks.insert(task) // Store the task for cancellation
    }

    func stopAllTasks() {
        for task in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
        pageHandlingTask?.cancel()
        pageHandlingTask = nil
    }

    override func reloadView() {
        defaultSitemap = Preferences.currentHomePreferences.defaultSitemap
        logger.debug("Reload view")
        selectSitemap()
    }

    override func viewName() -> String {
        "sitemap"
    }

    // This is mainly used for navigting to a specific sitemap and path from notifications
    override func pushSitemap(name: String, path: String?) async {
        guard let activeConnection = await NetworkTracker.shared.waitForActiveConnection() else {
            logger.error("pushSitemap: No active connection available")
            return
        }

        logger.info("pushSitemap: pushing page")

        guard let baseUrl = URL(string: activeConnection.configuration.url) else {
            logger.error("pushSitemap: Invalid base URL")
            return
        }

        var url = baseUrl.appendingPathComponent("rest")
            .appendingPathComponent("sitemaps")
            .appendingPathComponent(name)

        if let subpath = path {
            url.appendPathComponent(subpath)
        }

        guard let newViewController = storyboard?.instantiateViewController(withIdentifier: "OpenHABPageViewController") as? OpenHABSitemapViewController else {
            logger.error("pushSitemap: Failed to instantiate OpenHABSitemapViewController")
            return
        }

        newViewController.pageUrl = url.absoluteString
        newViewController.openHABRootUrl = activeConnection.configuration.url
        navigationController?.pushViewController(newViewController, animated: true)
    }
}

extension OpenHABSitemapViewController: GenericUITableViewCellTouchEventDelegate {
    func touchDown() {
        isUserInteracting = true
    }

    func touchUp() {
        isUserInteracting = false
        if isWaitingToReload {
            widgetTableView.reloadData()
            refreshControl?.endRefreshing()
        }
        isWaitingToReload = false
    }
}

extension OpenHABSitemapViewController {
    func configureTableView() {
        widgetTableView.dataSource = self
        widgetTableView.delegate = self
    }

    func registerTableViewCells() {
        widgetTableView.register(cellType: MapViewTableViewCell.self)
        widgetTableView.register(cellType: NewImageUITableViewCell.self)
        widgetTableView.register(cellType: VideoUITableViewCell.self)
    }

    @objc
    func handleRefresh(_ refreshControl: UIRefreshControl?) {
        startPageHandling()
        widgetTableView.reloadData()
        widgetTableView.layoutIfNeeded()
    }

    func restart() {
        if sitemapViewController == self {
            logger.info("I am a rootViewController!")

        } else {
            sitemapViewController?.pageUrl = ""
            navigationController?.popToRootViewController(animated: true)
        }
    }

    func relevantWidget(indexPath: IndexPath) -> OpenHABWidget? {
        relevantPage?.widgets[safe: indexPath.row]
    }

    public func updateWidgetTableView() {
        UIView.performWithoutAnimation {
            widgetTableView.beginUpdates()
            widgetTableView.endUpdates()
        }
    }

    func updateUI(with page: OpenHABPage) {
        currentPage = page

        if isFiltering {
            filterContentForSearchText(searchController.searchBar.text)
        }

        currentPage?.sendCommand = { [weak self] item, command in
            self?.sendCommand(item, commandToSend: command)
        }

        // isUserInteracting fixes https://github.com/openhab/openhab-ios/issues/646 where reloading while the user is interacting can have unintended consequences
        if !isUserInteracting {
            widgetTableView.reloadData()
            refreshControl?.endRefreshing()
        } else {
            isWaitingToReload = true
        }
        // on initial load ??? refreshControl?.endRefreshing()

        widgetTableView.reloadData()
        parent?.navigationItem.title = currentPage?.title.components(separatedBy: "[")[0]
    }

    // Select sitemap
    func selectSitemap() {
        Task {
            do {
                guard let activeConnection = NetworkTracker.shared.activeConnection else {
                    throw OpenHABSitemapError.noActiveConnection
                }
                logger.debug("Running selectSitemap for URL: \(activeConnection.configuration.url)")

                openAPIService = try OpenAPIService(connectionConfiguration: activeConnection.configuration)
                sitemaps = try await openAPIService?.openHABSitemaps() ?? []

                guard let openAPIService else {
                    logger.error("Failed to load openAPIService")
                    return
                }
                await pageLoader?.updateAPIService(newService: openAPIService)

                switch sitemaps.count {
                case 2...:
                    if !self.defaultSitemap.isEmpty {
                        if let sitemapToOpen = sitemap(byName: self.defaultSitemap) {
                            if self.currentPage?.pageId != sitemapToOpen.name {
                                self.currentPage?.widgets.removeAll() // NOTE: remove all widgets to ensure cells get invalidated
                            }
                            pageUrl = sitemapToOpen.homepageLink
                            startPageHandling()
                        } else {
                            showSideMenu()
                        }
                    } else {
                        showSideMenu()
                    }
                case 1:
                    pageUrl = sitemaps[0].homepageLink
                    startPageHandling()
                case ...0:
                    showPopupMessage(seconds: 5, title: NSLocalizedString("warning", comment: ""), message: NSLocalizedString("empty_sitemap", comment: ""), theme: .warning)
                    showSideMenu()
                default: break
                }
                widgetTableView.reloadData()
            } catch _ as OpenAPIServiceError {
                logger.debug("OpenAPIService Error on OpenHABSitemapViewController")
            } catch let error as OpenHABSitemapError {
                logger.error("OpenHABSitemap Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.showPopupMessage(
                        seconds: 5,
                        title: NSLocalizedString("error", comment: ""),
                        message: error.localizedDescription,
                        theme: .error
                    )
                }
            } catch {
                logger.error("\(error.localizedDescription)")
                DispatchQueue.main.async {
                    if let urlError = error as? URLError, urlError.code == .clientCertificateRejected {
                        self.showPopupMessage(
                            seconds: 5,
                            title: NSLocalizedString("error", comment: ""),
                            message: NSLocalizedString("ssl_certificate_error", comment: ""),
                            theme: .error
                        )
                    } else {
                        self.showPopupMessage(
                            seconds: 5,
                            title: NSLocalizedString("error", comment: ""),
                            message: error.localizedDescription,
                            theme: .error
                        )
                    }
                }
            }
        }
    }

    func startPageHandling() {
        pageHandlingTask?.cancel()

        guard !pageUrl.isEmpty else {
            logger.error("startPageHandling: Cannot run with empty pageUrl")
            return
        }

        logger.info("🚀 Starting page load and long polling flow...")

        pageHandlingTask = Task {
            do {
                // Initial page load

                guard let configuration = NetworkTracker.shared.activeConnection?.configuration else {
                    throw NetworkTrackerError.noActiveConnection
                }

                if openAPIService == nil {
                    openAPIService = try OpenAPIService(connectionConfiguration: configuration)
                }

                let initialPage = try await openAPIService?.pollDataForPage(
                    sitemapname: defaultSitemap,
                    pageId: pageId,
                    longPolling: false
                )

                // Alternative 2 to be tested.
                //                await pageLoader?.updatePageConfig(newPageId: pageId, newSitemap: defaultSitemap)
                //                guard let page = try await pageLoader?.fetchPage(longPolling: true) else { return }
                //
                try Task.checkCancellation()
                if let page = initialPage {
                    await MainActor.run {
                        self.updateUI(with: page)
                    }
                }

                // Start long polling loop
                while !Task.isCancelled {
                    let page = try await openAPIService?.pollDataForPage(
                        sitemapname: defaultSitemap,
                        pageId: pageId,
                        longPolling: true
                    )
                    try Task.checkCancellation()

                    if let page {
                        await MainActor.run {
                            self.updateUI(with: page)
                        }
                    }
                }
            } catch is CancellationError {
                logger.info("🔁 pageHandlingTask was cancelled")
            } catch let error as DecodingError {
                logger.error("DecodingError \(error.localizedDescription)")
            } catch let error as ClientError {
                if let urlError = error.underlyingError as? URLError {
                    switch urlError.code {
                    case .cancelled:
                        logger.info("Task was cancelled - URLError code: .cancelled")
                    case .timedOut:
                        logger.info("Task timed out - URLError code: .timedOut")
                    default:
                        logger.info("URLError: \(urlError.localizedDescription)")
                    }
                } else {
                    logger.error("\(error.localizedDescription)")
                }
            } catch let openAPIError as OpenAPIServiceError {
                logger.info("On pageHandling \(openAPIError)")
            } catch {
                logger.error("❌ pageHandlingTask error: \(error.localizedDescription)")
                await MainActor.run {
                    self.showPopupMessage(
                        seconds: 5,
                        title: NSLocalizedString("error", comment: ""),
                        message: error.localizedDescription,
                        theme: .error
                    )
                }
            }
        }
    }

    // load settings into local properties
    func loadSettings() {
        defaultSitemap = Preferences.currentHomePreferences.defaultSitemap
        idleOff = Preferences.idleOff
        iconType = IconType(rawValue: Preferences.currentHomePreferences.iconType) ?? .png
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

    @discardableResult
    func pageNetworkStatusChanged() -> Bool {
        logger.info("OpenHABSitemapViewController pageNetworkStatusChange")

        guard !pageUrl.isEmpty else { return false }

        let currentStatus = NetworkTracker.shared.status

        // First run
        if !pageNetworkStatusAvailable {
            pageNetworkStatus = currentStatus
            pageNetworkStatusAvailable = true
            return false
        }

        if pageNetworkStatus == currentStatus {
            return false
        } else {
            pageNetworkStatus = currentStatus
            return true
        }
    }

    func filterContentForSearchText(_ searchText: String?, scope: String = "All") {
        guard let searchText else { return }

        filteredPage = currentPage?.filter {
            $0.label.lowercased().contains(searchText.lowercased()) && $0.type != .frame
        }

        filteredPage?.sendCommand = { [weak self] item, command in
            self?.sendCommand(item, commandToSend: command)
        }

        UIView.performWithoutAnimation {
            widgetTableView.reloadData()
        }
    }

    func sendCommand(_ item: OpenHABItem?, commandToSend command: String?) {
        if let item, let command {
            sendCommand(itemname: item.name, command: command)
        }
    }

    func sendCommand(itemname: String, command: String) {
        Task { try await openAPIService?.sendItemCommand(itemname: itemname, command: command) }
    }
}

// MARK: - UISearchResultsUpdating

extension OpenHABSitemapViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        logger.info("Search updated: \(searchController.searchBar.text ?? "")")
        filterContentForSearchText(searchController.searchBar.text)
    }
}

// MARK: - UISearchBarDelegate

extension OpenHABSitemapViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        filterContentForSearchText(searchBar.text)
        searchBar.resignFirstResponder()
    }
}

// MARK: - ColorPickerCellDelegate

extension OpenHABSitemapViewController: @preconcurrency ColorPickerCellDelegate {
    func didPressColorButton(_ cell: ColorPickerCell?) {
        let colorPickerViewController = storyboard?.instantiateViewController(withIdentifier: "ColorPickerViewController") as? ColorPickerViewController
        if let cell {
            let widget = relevantPage?.widgets[widgetTableView.indexPath(for: cell)?.row ?? 0]
            colorPickerViewController?.title = widget?.labelText
            colorPickerViewController?.widget = widget
        }
        if let colorPickerViewController {
            navigationController?.pushViewController(colorPickerViewController, animated: true)
        }
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension OpenHABSitemapViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        relevantPage?.widgets.count ?? 0
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
                // calculate webview/mapview height and return it. Limited to UIScreen.main.bounds.height
                let heightValue = height * 44
                logger.info("Webview/Mapview height would be \(heightValue)")
                return min(UIScreen.main.bounds.height, CGFloat(heightValue))
            } else {
                // return default height for webview/mapview as 8 rows
                return 44.0 * 8
            }
        default: return 44.0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let widget: OpenHABWidget = relevantWidget(indexPath: indexPath) else {
            // this should never be the case
            let cell = tableView.dequeueReusableCell(for: indexPath) as GenericUITableViewCell
            cell.displayWidget()
            cell.touchEventDelegate = self
            cell.separatorInset = UIEdgeInsets(top: 0, left: 60, bottom: 0, right: 0)
            return cell
        }

        let provider = WidgetCellFactory.provider(for: widget)
        let cell = provider.dequeue(from: tableView, at: indexPath)
        provider.configure(cell: cell, for: widget, controller: self)

        var iconColor = widget.iconColor
        if iconColor.isEmpty, traitCollection.userInterfaceStyle == .dark {
            iconColor = "white"
        }
        // No icon will be displazed for cells that conform to NoIconDisplayableCell protocol
        if !(cell is any NoIconDisplayableCell) {
            if !widget.icon.isEmpty {
                if let urlc = Endpoint.icon(
                    rootUrl: openHABRootUrl,
                    version: NetworkTracker.shared.activeConnection?.version ?? 2,
                    icon: widget.icon,
                    state: widget.iconState(),
                    iconType: iconType,
                    iconColor: iconColor
                ).url {
                    var imageRequest = URLRequest(url: urlc)
                    imageRequest.timeoutInterval = 10.0
                    cell.imageView?.kf.setImage(
                        with: KF.ImageResource(downloadURL: urlc, cacheKey: urlc.path + (urlc.query ?? "")),
                        placeholder: nil,
                        options: [.processor(OpenHABImageProcessor())]
                    ) { result in
                        switch result {
                        case .success:
                            DispatchQueue.main.async {
                                cell.setNeedsLayout()
                            }
                        case let .failure(error):
                            self.logger.error("Image loading failed for widget \(widget.label) : \(error.localizedDescription)")
                        }
                    }
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
            cell.touchEventDelegate = self
        }

        // Check if this is not the last row in the widgets list
        if indexPath.row < (relevantPage?.widgets.count ?? 1) - 1 {
            let nextWidget: OpenHABWidget? = relevantPage?.widgets[indexPath.row + 1]
            if let type = nextWidget?.type, type.isAny(of: .frame, .image, .video, .webview, .chart) {
                cell.separatorInset = UIEdgeInsets.zero
            } else if !(widget.type == .frame) {
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
        if let index = widgetTableView.indexPathForSelectedRow {
            widgetTableView.deselectRow(at: index, animated: false)
        }

        guard let widget: OpenHABWidget = relevantWidget(indexPath: indexPath) else { return }

        if let linkedPage = widget.linkedPage {
            logger.info("Selected linked page: \(linkedPage.link)")
            stopAllTasks()
            let newViewController = (storyboard?.instantiateViewController(withIdentifier: "OpenHABPageViewController") as? OpenHABSitemapViewController)!
            newViewController.title = linkedPage.title.components(separatedBy: "[")[0]
            newViewController.pageId = linkedPage.pageId
            newViewController.pageUrl = linkedPage.link
            newViewController.openHABRootUrl = openHABRootUrl
            navigationController?.pushViewController(newViewController, animated: true)
        } else if widget.type == .selection {
            let selectionItemState = widget.item?.state
            logger.info("Selected selection widget in status: \(selectionItemState ?? "unknown")")
            let hostingController = UIHostingController(
                rootView: SelectionView(
                    mappings: widget.mappingsOrItemOptions,
                    selectionItemState: selectionItemState
                ) { selectedMappingIndex in
                    let selectedMapping: OpenHABWidgetMapping = widget.mappingsOrItemOptions[selectedMappingIndex]
                    self.sendCommand(widget.item, commandToSend: selectedMapping.command)
                }
            )
            hostingController.title = widget.labelText
            navigationController?.pushViewController(hostingController, animated: true)
        } else if widget.type == .input {
            let hint = widget.inputHint
            let textExtractor: ((UIAlertController) -> String?)?
            let textFieldAdder: ((UITextField) -> Void)?

            switch hint {
            case .date, .time, .datetime:
                // value setting is handeled by the cell itself
                textExtractor = nil
                textFieldAdder = nil
            case .number:
                textFieldAdder = { textField in
                    textField.text = widget.state
                    textField.clearButtonMode = .always
                    textField.delegate = self
                    textField.keyboardType = .numbersAndPunctuation
                }
                // replace expected decimal separator
                textExtractor = { $0.textFields?[0].text?.replacingOccurrences(of: NSLocale.current.decimalSeparator ?? "", with: ".") }
            case .text:
                textFieldAdder = { textField in
                    textField.text = widget.state
                    textField.clearButtonMode = .always
                    textField.keyboardType = .default
                }
                textExtractor = { $0.textFields?[0].text }
            case .unknown:
                textExtractor = nil
                textFieldAdder = nil
            }
            guard let textExtractor, let textFieldAdder else {
                return
            }

            // TODO: proper texts instead of hardcoded values
            let alert = UIAlertController(
                title: "Enter new value",
                message: "Current value for \(widget.label) is \(widget.state)",
                preferredStyle: .alert
            )
            alert.addTextField(configurationHandler: textFieldAdder)
            let sendAction = UIAlertAction(title: "Set value", style: .destructive) { [weak self] _ in
                self?.sendCommand(widget.item, commandToSend: textExtractor(alert))
            }
            alert.addAction(sendAction)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.preferredAction = sendAction
            present(alert, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? any GenericCellCacheProtocol {
            // invalidate cache only if the cell is not visible or the datasource is empty (eg. sitemap change)
            if tableView.indexPathsForVisibleRows == nil || !tableView.indexPathsForVisibleRows!.contains(indexPath) || currentPage == nil || currentPage!.widgets.isEmpty {
                cell.invalidateCache()
            }
        }
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        if let cell = tableView.cellForRow(at: indexPath) as? GenericUITableViewCell, cell.widget.type == .text, let text = cell.widget?.labelValue ?? cell.widget?.labelText, !text.isEmpty {
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
                let copy = UIAction(title: NSLocalizedString("copy_label", comment: ""), image: UIImage(systemSymbol: .squareAndArrowUp)) { _ in
                    UIPasteboard.general.string = text
                }

                return UIMenu(title: "", children: [copy])
            }
        }

        return nil
    }
}

extension OpenHABSitemapViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let decimalSeparator = NSLocale.current.decimalSeparator ?? ""
        let oldString = (textField.text ?? "")
        let wholeNumberRegex = /^-?[0-9]*$/

        // check for deletion
        return string.isEmpty
            // check for new negative sign
            || (
                !string.starts(with: "-") // new string does not add negative sign
                    || range.location == 0 // new string adds negative sign to beginning
                    && (
                        !oldString.starts(with: "-") // old string does not contain negative sign
                            || range.length > 0
                    )
            ) // new string replaces negative sign in old string
            // check for old negative sign
            && (
                oldString.isEmpty
                    || !oldString.starts(with: "-") // old string does not start with negative sign
                    || range.location > 0 // new string starts after negative sign in old string
                    || range.length > 0
            ) // new string replaces negative sign in old string
            // check for decimal signs
            && (
                string.firstRange(of: wholeNumberRegex) != nil // new string is whole number
                    || (
                        string.replacing(decimalSeparator, with: "", maxReplacements: 1)
                            .firstRange(of: wholeNumberRegex) != nil // new string is valid decimal number
                            && !(oldString as NSString).replacingCharacters(in: range, with: "").contains(decimalSeparator)
                    )
            ) // old string without replaced range not yet contains decimal separator
    }
}

// MARK: Kingfisher authentication with NSURLCredential

extension OpenHABSitemapViewController: AuthenticationChallengeResponsible {
    func downloader(_ downloader: ImageDownloader,
                    didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        await onReceiveSessionChallenge(with: challenge)
    }

    func downloader(_ downloader: ImageDownloader,
                    task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        onReceiveSessionTaskChallenge(with: challenge)
    }
}
