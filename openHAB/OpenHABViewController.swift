//
//  OpenHABViewController.swift
//  openHAB
//
//  Created by Victor Belov on 12/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import AVFoundation
import AVKit
import os.log
import SDWebImage
import SDWebImageSVGCoder
import SideMenu
import SwiftMessages
import UIKit

private let OpenHABViewControllerMapViewCellReuseIdentifier = "OpenHABViewControllerMapViewCellReuseIdentifier"
private let OpenHABViewControllerImageViewCellReuseIdentifier = "OpenHABViewControllerImageViewCellReuseIdentifier"

enum TargetController {
    case settings
    case notifications
}
protocol ModalHandler: class {
    func modalDismissed(to: TargetController)
}

class OpenHABViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, OpenHABTrackerDelegate, OpenHABSitemapPageDelegate, OpenHABSelectionTableViewControllerDelegate, ColorPickerUITableViewCellDelegate, AFRememberingSecurityPolicyDelegate, ClientCertificateManagerDelegate, NewImageUITableViewCellDelegate, ModalHandler {

    var tracker: OpenHABTracker?

    private var selectedWidgetRow: Int = 0
    private var currentPageOperation: OpenHABHTTPRequestOperation?
    private var commandOperation: OpenHABHTTPRequestOperation?

    @IBOutlet var widgetTableView: UITableView!
    var pageUrl = ""
    var openHABRootUrl = ""
    var openHABUsername = ""
    var openHABPassword = ""
    var defaultSitemap = ""
    var idleOff = false
    var sitemaps: [OpenHABSitemap] = []
    var currentPage: OpenHABSitemapPage?
    var selectionPicker: UIPickerView?
    var pageNetworkStatus: Reachability.Connection?
    var pageNetworkStatusAvailable = false
    var toggle: Int = 0
    var deviceToken = ""
    var deviceId = ""
    var deviceName = ""
    var atmosphereTrackingId = ""
    var refreshControl: UIRefreshControl?
    var iconType: IconType = .png

    func modalDismissed(to: TargetController) {
        switch to {
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
        }
    }

    func openHABTracked(_ openHABUrl: String?) {
        os_log("OpenHABViewController openHAB URL =  %{PUBLIC}@", log: .remoteAccess, type: .error, openHABUrl ?? "")

        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }
        openHABRootUrl = openHABUrl ?? ""
        appData?.openHABRootUrl = openHABRootUrl

        if let pageToLoadUrl = Endpoint.tracker(openHABRootUrl: openHABRootUrl).url {
            var pageRequest = URLRequest(url: pageToLoadUrl)

            pageRequest.setAuthCredentials(openHABUsername, openHABPassword)
            pageRequest.timeoutInterval = 10.0
            let versionPageOperation = OpenHABHTTPRequestOperation(request: pageRequest, delegate: self)
            versionPageOperation.setCompletionBlockWithSuccess({ operation, responseObject in
                os_log("This is an openHAB 2.X", log: .remoteAccess, type: .info)
                self.appData?.openHABVersion = 2
                DispatchQueue.main.async {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                }
                self.selectSitemap()
            }, failure: { operation, error in
                os_log("This is an openHAB 1.X", log: .remoteAccess, type: .info)
                self.appData?.openHABVersion = 1
                DispatchQueue.main.async {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                }
                os_log("On Tracking %{PUBLIC}@ %d", log: .remoteAccess, type: .error, error.localizedDescription, Int(operation.response?.statusCode ?? 0))
                self.selectSitemap()
            })
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = true
            }
            versionPageOperation.start()
        }
    }

    func sendCommand(_ item: OpenHABItem?, commandToSend command: String?) {
        if let commandUrl = URL(string: item?.link ?? "") {
            var commandRequest = URLRequest(url: commandUrl)

            commandRequest.httpMethod = "POST"
            commandRequest.httpBody = command?.data(using: .utf8)
            commandRequest.setAuthCredentials(openHABUsername, openHABPassword)
            commandRequest.setValue("text/plain", forHTTPHeaderField: "Content-type")
            if commandOperation != nil {
                commandOperation?.cancel()
                commandOperation = nil
            }
            commandOperation = OpenHABHTTPRequestOperation(request: commandRequest, delegate: self)
            commandOperation?.setCompletionBlockWithSuccess({ operation, responseObject in
                os_log("Command sent!", log: .remoteAccess, type: .info)
            }, failure: { operation, error in
                os_log("%{PUBLIC}@ %d", log: .default, type: .error, error.localizedDescription, Int(operation.response?.statusCode ?? 0))
            })
            os_log("Timeout %{PUBLIC}g", log: .default, type: .info, commandRequest.timeoutInterval)
            if let link = item?.link {
                os_log("OpenHABViewController posting %{PUBLIC}@ command to %{PUBLIC}@", log: .default, type: .info, command  ?? "", link)
                os_log("%{PUBLIC}@", log: .default, type: .info, commandRequest.debugDescription)
            }
            commandOperation?.start()
        }
    }

    // Here goes everything about view loading, appearing, disappearing, entering background and becoming active
    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("OpenHABViewController viewDidLoad", log: .default, type: .info)

        pageNetworkStatus = nil //NetworkStatus(rawValue: -1)
        sitemaps = []
        widgetTableView.tableFooterView = UIView()
        NotificationCenter.default.addObserver(self, selector: #selector(OpenHABViewController.didEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(OpenHABViewController.didBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)

        self.registerTableViewCells()
        self.configureTableView()

        refreshControl = UIRefreshControl()
        refreshControl?.backgroundColor = UIColor.groupTableViewBackground

        refreshControl?.addTarget(self, action: #selector(OpenHABViewController.handleRefresh(_:)), for: .valueChanged)
        if let refreshControl = refreshControl {
            widgetTableView.addSubview(refreshControl)
        }
        if let refreshControl = refreshControl {
            widgetTableView.sendSubviewToBack(refreshControl)
        }

        let rightDrawerButton = UIBarButtonItem.menuButton(self, action: #selector(OpenHABViewController.rightDrawerButtonPress(_:)), imageName: "hamburgerMenuIcon-50.png")
        navigationItem.setRightBarButton (rightDrawerButton, animated: true)

        setupSideMenu()
    }

    fileprivate func setupSideMenu() {
        // Define the menus

        SideMenuManager.default.menuRightNavigationController = storyboard!.instantiateViewController(withIdentifier: "RightMenuNavigationController") as? UISideMenuNavigationController

        // Enable gestures. The left and/or right menus must be set up above for these to work.
        // Note that these continue to work on the Navigation Controller independent of the View Controller it displays!
        SideMenuManager.default.menuAddPanGestureToPresent(toView: self.navigationController!.navigationBar)
        SideMenuManager.default.menuAddScreenEdgePanGesturesToPresent(toView: self.navigationController!.view)

        SideMenuManager.default.menuFadeStatusBar = false
    }

    func configureTableView() {
        widgetTableView.dataSource = self
        widgetTableView.delegate = self
    }

    func registerTableViewCells() {

        widgetTableView.register(MapViewTableViewCell.self, forCellReuseIdentifier: OpenHABViewControllerMapViewCellReuseIdentifier)
        widgetTableView.register(cellType: MapViewTableViewCell.self)
        widgetTableView.register(NewImageUITableViewCell.self, forCellReuseIdentifier: OpenHABViewControllerImageViewCellReuseIdentifier)
        widgetTableView.register(cellType: VideoUITableViewCell.self)

    }

    @objc func handleRefresh(_ refreshControl: UIRefreshControl?) {
        loadPage(false)
        widgetTableView.reloadData()
        widgetTableView.layoutIfNeeded()
    }

    @objc func handleApsRegistration(_ note: Notification?) {
        os_log("handleApsRegistration", log: .notifications, type: .info)
        let theData = note?.userInfo
        if theData != nil {
            deviceId = theData?["deviceId"] as? String ?? ""
            deviceToken = theData?["deviceToken"] as? String ?? ""
            deviceName = theData?["deviceName"] as? String ?? ""
            doRegisterAps()
        }
    }

    @objc func rightDrawerButtonPress(_ sender: Any?) {
        performSegue(withIdentifier: "sideMenu", sender: nil)
    }

    func doRegisterAps() {
        if let prefsURL = UserDefaults.standard.string(forKey: "remoteUrl"), prefsURL.contains("openhab.org") {
            if deviceId != "" && deviceToken != "" && deviceName != "" {
                os_log("Registering notifications with %{PUBLIC}@", log: .notifications, type: .info, prefsURL)
                if let registrationUrl = Endpoint.appleRegistration(prefsURL: prefsURL, deviceToken: deviceToken, deviceId: deviceId, deviceName: deviceName).url {
                    var registrationRequest = URLRequest(url: registrationUrl)
                    os_log("Registration URL = %{PUBLIC}@", log: .notifications, type: .info, registrationUrl.absoluteString)
                    registrationRequest.setAuthCredentials(openHABUsername, openHABPassword)
                    let registrationOperation = OpenHABHTTPRequestOperation(request: registrationRequest, delegate: self)
                    registrationOperation.setCompletionBlockWithSuccess({ operation, responseObject in
                        os_log("my.openHAB registration sent", log: .notifications, type: .info)
                    }, failure: { operation, error in
                        os_log("my.openHAB registration failed %{PUBLIC}@ %d", log: .notifications, type: .error, error.localizedDescription, Int(operation.response?.statusCode ?? 0))

                    })
                    registrationOperation.start()
                }
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        os_log("OpenHABViewController viewDidAppear", log: .viewCycle, type: .info)

        super.viewDidAppear(animated)
        widgetTableView.reloadData() // reloading data for the first tableView serves another purpose, not exactly related to this question.
        widgetTableView.setNeedsLayout()
        widgetTableView.layoutIfNeeded()
        widgetTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        os_log("OpenHABViewController viewWillAppear", log: .viewCycle, type: .info)
        super.viewDidAppear(animated)
        // Load settings into local properties
        loadSettings()
        // Set authentication parameters to SDImag
        setSDImageAuth()
        // Disable idle timeout if configured in settings
        if idleOff {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        doRegisterAps()
        // if pageUrl == "" it means we are the first opened OpenHABViewController
        if pageUrl == "" {
            // Set self as root view controller
            appData?.rootViewController = self
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
    }

    override func viewWillDisappear(_ animated: Bool) {
        os_log("OpenHABViewController viewWillDisappear", log: .viewCycle, type: .info)
        if currentPageOperation != nil {
            currentPageOperation?.cancel()
            currentPageOperation = nil
        }
        super.viewWillDisappear(animated)
    }

    @objc func didEnterBackground(_ notification: Notification?) {
        os_log("OpenHABViewController didEnterBackground", log: .viewCycle, type: .info)
        if currentPageOperation != nil {
            currentPageOperation?.cancel()
            currentPageOperation = nil
        }
        UIApplication.shared.isIdleTimerDisabled = false
    }

    @objc func didBecomeActive(_ notification: Notification?) {
        os_log("OpenHABViewController didBecomeActive", log: .viewCycle, type: .info)
        // re disable idle off timer
        if idleOff {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        if isViewLoaded && view.window != nil && pageUrl != "" {
            if !pageNetworkStatusChanged() {
                os_log("OpenHABViewController isViewLoaded, restarting network activity", log: .viewCycle, type: .info)
                loadPage(false)
            } else {
                os_log("OpenHABViewController network status changed while it was inactive", log: .viewCycle, type: .info)
                restart()
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

    // Here goes everything about our main UITableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if currentPage != nil {
            return currentPage?.widgets.count ?? 0
        } else {
            return 0
        }
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let widget: OpenHABWidget? = currentPage?.widgets[indexPath.row]
        switch widget?.type {
        case "Frame":
            if widget?.label.count ?? 0 > 0 {
                return 35.0
            } else {
                return 0
            }
        case "Video":
            return widgetTableView.frame.size.width * 0.75
        case "Image", "Chart":
            return UITableView.automaticDimension
        case "Webview", "Mapview":
            if let height = widget?.height, height.intValue != 0 {
                // calculate webview/mapview height and return it
                let heightValue = (Double(height) ?? 0.0) * 44
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

        let widget: OpenHABWidget? = currentPage?.widgets[indexPath.row]

        let cell: UITableViewCell

        switch widget?.type {
        case "Frame":
            cell = tableView.dequeueReusableCell(for: indexPath) as FrameUITableViewCell
        case "Switch":
            if widget?.mappings.count ?? 0 > 0 {
                cell = tableView.dequeueReusableCell(for: indexPath) as SegmentedUITableViewCell
                //RollershutterItem changed to Rollershutter in later builds of OH2
            } else if (widget?.item?.type == "RollershutterItem") || (widget?.item?.type == "Rollershutter") || ((widget?.item?.type == "Group") && (widget?.item?.groupType == "Rollershutter")) {
                cell = tableView.dequeueReusableCell(for: indexPath) as RollershutterUITableViewCell
            } else {
                cell = tableView.dequeueReusableCell(for: indexPath) as SwitchUITableViewCell
            }
        case "Setpoint":
            cell = tableView.dequeueReusableCell(for: indexPath) as SetpointUITableViewCell
        case "Slider":
            cell = tableView.dequeueReusableCell(for: indexPath) as SliderUITableViewCell
        case "Selection":
            cell = tableView.dequeueReusableCell(for: indexPath) as SelectionUITableViewCell
        case "Colorpicker":
            cell = tableView.dequeueReusableCell(for: indexPath) as ColorPickerUITableViewCell
            (cell as? ColorPickerUITableViewCell)?.delegate = self
        case "Image", "Chart":
            cell = tableView.dequeueReusableCell(withIdentifier: OpenHABViewControllerImageViewCellReuseIdentifier, for: indexPath) as! NewImageUITableViewCell
            (cell as? NewImageUITableViewCell)?.delegate = self
        case "Video":
            cell = tableView.dequeueReusableCell(withIdentifier: "VideoUITableViewCell", for: indexPath) as! VideoUITableViewCell
        case "Webview":
            cell = tableView.dequeueReusableCell(for: indexPath) as WebUITableViewCell
        case "Mapview":
            cell = (tableView.dequeueReusableCell(withIdentifier: OpenHABViewControllerMapViewCellReuseIdentifier) as? MapViewTableViewCell)!
        default:
            cell = tableView.dequeueReusableCell(for: indexPath) as GenericUITableViewCell
        }

        // No icon is needed for image, video, frame and web widgets
        if (widget?.icon != nil) && !( (cell is NewImageUITableViewCell) || (cell is VideoUITableViewCell) || (cell is FrameUITableViewCell) || (cell is WebUITableViewCell) ) {

            let urlc = Endpoint.icon(rootUrl: openHABRootUrl,
                                     version: appData?.openHABVersion ?? 2,
                                     icon: widget?.icon,
                                     value: widget?.item?.state ?? "",
                                     iconType: iconType).url
            switch iconType {
            case .png :
                cell.imageView?.sd_setImage(with: urlc, placeholderImage: UIImage(named: "blankicon.png"), options: .imageOptionsIgnoreInvalidCertIfDefined)
            case .svg:
                let SVGCoder = SDImageSVGCoder.shared
                SDImageCodersManager.shared.addCoder(SVGCoder)
                cell.imageView?.sd_setImage(with: urlc, placeholderImage: UIImage(named: "blankicon.png"), options: .imageOptionsIgnoreInvalidCertIfDefined)
            }
        }

        if cell is FrameUITableViewCell {
            cell.backgroundColor = UIColor.groupTableViewBackground
        } else {
            cell.backgroundColor = UIColor.white
        }

        if let cell = cell as? VideoUITableViewCell {
            let url = URL(string: widget?.url ?? "")
            let avPlayer = AVPlayer(url: url!)
            cell.playerView?.playerLayer.player = avPlayer
            return cell
        }

        if let cell = cell as? GenericUITableViewCell {
            cell.widget = widget
            cell.displayWidget()
        }

        // Check if this is not the last row in the widgets list
        if indexPath.row < (currentPage?.widgets.count ?? 1) - 1 {

            let nextWidget: OpenHABWidget? = currentPage?.widgets[indexPath.row + 1]
            if nextWidget?.type == "Frame" || nextWidget?.type == "Image" || nextWidget?.type == "Video" || nextWidget?.type == "Webview" || nextWidget?.type == "Chart" {
                cell.separatorInset = UIEdgeInsets.zero
            } else if !(widget?.type == "Frame") {
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

        guard let videoCell = (cell as? VideoUITableViewCell) else { return }
        videoCell.playerView.player?.play()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let widget: OpenHABWidget? = currentPage?.widgets[indexPath.row]
        if widget?.linkedPage != nil {
            if let link = widget?.linkedPage?.link {
                os_log("Selected %{PUBLIC}@", log: .viewCycle, type: .info, link)
            }
            selectedWidgetRow = indexPath.row
            let newViewController = storyboard?.instantiateViewController(withIdentifier: "OpenHABPageViewController") as? OpenHABViewController
            newViewController?.pageUrl = widget?.linkedPage?.link ?? ""
            newViewController?.openHABRootUrl = openHABRootUrl
            if let newViewController = newViewController {
                navigationController?.pushViewController(newViewController, animated: true)
            }
        } else if widget?.type == "Selection" {
            os_log("Selected selection widget", log: .viewCycle, type: .info)

            selectedWidgetRow = indexPath.row
            let selectionViewController = storyboard?.instantiateViewController(withIdentifier: "OpenHABSelectionTableViewController") as? OpenHABSelectionTableViewController
            let selectedWidget: OpenHABWidget? = currentPage?.widgets[selectedWidgetRow]
            selectionViewController?.mappings = (selectedWidget?.mappings)!
            selectionViewController?.delegate = self
            selectionViewController?.selectionItem = selectedWidget?.item
            if let selectionViewController = selectionViewController {
                navigationController?.pushViewController(selectionViewController, animated: true)
            }
        }
        if let index = widgetTableView.indexPathForSelectedRow {
            widgetTableView.deselectRow(at: index, animated: false)
        }
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let videoCell = cell as? VideoUITableViewCell else { return }
        videoCell.playerView.player?.pause()
        videoCell.playerView.player = nil
    }

    func didLoadImageOf(_ cell: NewImageUITableViewCell?) {
        UIView.performWithoutAnimation {
            widgetTableView.beginUpdates()
            widgetTableView.endUpdates()
        }
    }

    func evaluateServerTrust(_ policy: AFRememberingSecurityPolicy?, summary certificateSummary: String?, forDomain domain: String?) {
        DispatchQueue.main.async(execute: {
            let alertView = UIAlertController(title: "SSL Certificate Warning", message: "SSL Certificate presented by \(certificateSummary ?? "") for \(domain ?? "") is invalid. Do you want to proceed?", preferredStyle: .alert)
            alertView.addAction(UIAlertAction(title: "Abort", style: .default) { _ in policy?.evaluateResult = .deny })
            alertView.addAction(UIAlertAction(title: "Once", style: .default) { _ in  policy?.evaluateResult = .permitOnce })
            alertView.addAction(UIAlertAction(title: "Always", style: .default) { _ in policy?.evaluateResult = .permitAlways })
            self.present(alertView, animated: true) {}
        })
    }

    func evaluateCertificateMismatch(_ policy: AFRememberingSecurityPolicy?, summary certificateSummary: String?, forDomain domain: String?) {
        DispatchQueue.main.async(execute: {
            let alertView = UIAlertController(title: "SSL Certificate Warning", message: "SSL Certificate presented by \(certificateSummary ?? "") for \(domain ?? "") doesn't match the record. Do you want to proceed?", preferredStyle: .alert)
            alertView.addAction(UIAlertAction(title: "Abort", style: .default) { _ in  policy?.evaluateResult = .deny })
            alertView.addAction(UIAlertAction(title: "Once", style: .default) { _ in  policy?.evaluateResult = .permitOnce })
            alertView.addAction(UIAlertAction(title: "Always", style: .default) { _ in policy?.evaluateResult = .permitAlways })
            self.present(alertView, animated: true) {}
        })
    }

    func askForClientCertificateImport(_ clientCertificateManager: ClientCertificateManager?) {
        let alertController = UIAlertController(title: "Client Certificate Import", message: "Import client certificate into the keychain?", preferredStyle: .alert)

        let okay = UIAlertAction(title: "Okay", style: .default) { (action: UIAlertAction) in
            clientCertificateManager!.clientCertificateAccepted(password: nil)
        }

        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (action: UIAlertAction) in
            clientCertificateManager!.clientCertificateRejected()
        }

        alertController.addAction(okay)
        alertController.addAction(cancel)
        self.present(alertController, animated: true, completion: nil)
    }

    func askForCertificatePassword(_ clientCertificateManager: ClientCertificateManager?) {
        let alertController = UIAlertController(title: "Client Certificate Import", message: "Password required for import.", preferredStyle: .alert)

        let okay = UIAlertAction(title: "Okay", style: .default) { (action: UIAlertAction) in
            let txtField = alertController.textFields?.first
            let password = txtField?.text

            clientCertificateManager!.clientCertificateAccepted(password: password)
        }

        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (action: UIAlertAction) in
            clientCertificateManager!.clientCertificateRejected()
        }

        alertController.addTextField { (textField) in
            textField.placeholder = "Password"
            textField.isSecureTextEntry = true
        }

        alertController.addAction(okay)
        alertController.addAction(cancel)
        self.present(alertController, animated: true, completion: nil)
    }

    func alertClientCertificateError(_ clientCertificateManager: ClientCertificateManager?, errMsg: String) {
        let alertController = UIAlertController(title: "Client Certificate Import", message: errMsg, preferredStyle: .alert)

        let okay = UIAlertAction(title: "Okay", style: .default)

        alertController.addAction(okay)
        self.present(alertController, animated: true, completion: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        os_log("OpenHABViewController prepareForSegue %{PUBLIC}@", log: .viewCycle, type: .info, segue.identifier ?? "")

        switch segue.identifier {
        case "showPage":
            let newViewController = segue.destination as? OpenHABViewController
            let selectedWidget: OpenHABWidget? = currentPage?.widgets[selectedWidgetRow]
            newViewController?.pageUrl = selectedWidget?.linkedPage?.link ?? ""
            newViewController?.openHABRootUrl = openHABRootUrl
        case "showSelectionView": os_log("Selection seague", log: .viewCycle, type: .info)
        case "sideMenu":
            let navigation = segue.destination as? UINavigationController
            let drawer = navigation?.viewControllers[0] as? OpenHABDrawerTableViewController
            drawer?.openHABRootUrl = openHABRootUrl
            drawer?.delegate = self
        default: break
        }
    }

    // OpenHABTracker delegate methods
    func openHABTrackingProgress(_ message: String?) {
        os_log("OpenHABViewController %{PUBLIC}@", log: .viewCycle, type: .info, message ?? "")
        var config = SwiftMessages.Config()
        config.duration = .seconds(seconds: 3)
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

    // send command to an item

    // send command on selected selection widget mapping
    func didSelectWidgetMapping(_ selectedMappingIndex: Int) {
        let selectedWidget: OpenHABWidget? = currentPage?.widgets[selectedWidgetRow]
        let selectedMapping: OpenHABWidgetMapping? = selectedWidget?.mappings[selectedMappingIndex]
        sendCommand(selectedWidget?.item, commandToSend: selectedMapping?.command)
    }

    func didPressColorButton(_ cell: ColorPickerUITableViewCell?) {
        let colorPickerViewController = storyboard?.instantiateViewController(withIdentifier: "ColorPickerViewController") as? ColorPickerViewController
        if let cell = cell {
            colorPickerViewController?.widget = currentPage?.widgets[widgetTableView.indexPath(for: cell)?.row ?? 0]
        }
        if let colorPickerViewController = colorPickerViewController {
            navigationController?.pushViewController(colorPickerViewController, animated: true)
        }
    }

    // load our page and show it into UITableView
    func loadPage(_ longPolling: Bool) {
        if pageUrl == "" {
            return
        }
        os_log("pageUrl = %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, pageUrl)

        // If this is the first request to the page make a bulk call to pageNetworkStatusChanged
        // to save current reachability status.
        if !longPolling {
            _ = pageNetworkStatusChanged()
        }
        //let pageToLoadUrl = URL(string: pageUrl)
        guard let pageToLoadUrl = URL(string: pageUrl) else { return }
        var pageRequest = URLRequest(url: pageToLoadUrl)

        pageRequest.setAuthCredentials(openHABUsername, openHABPassword)
        // We accept XML only if openHAB is 1.X
        if appData?.openHABVersion == 1 {
            pageRequest.setValue("application/xml", forHTTPHeaderField: "Accept")
        }
        pageRequest.setValue("1.0", forHTTPHeaderField: "X-Atmosphere-Framework")
        if longPolling {
            os_log("long polling, so setting atmosphere transport", log: OSLog.remoteAccess, type: .info)
            pageRequest.setValue("long-polling", forHTTPHeaderField: "X-Atmosphere-Transport")
            pageRequest.timeoutInterval = 300.0
        } else {
            atmosphereTrackingId = ""
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            pageRequest.timeoutInterval = 10.0
        }
        if atmosphereTrackingId == "" {
            pageRequest.setValue(atmosphereTrackingId, forHTTPHeaderField: "X-Atmosphere-tracking-id")
        } else {
            pageRequest.setValue("0", forHTTPHeaderField: "X-Atmosphere-tracking-id")
        }
        if currentPageOperation != nil {
            currentPageOperation?.cancel()
            currentPageOperation = nil
        }
        currentPageOperation = OpenHABHTTPRequestOperation(request: pageRequest as URLRequest, delegate: self)

        // FIX Capturing 'self' strongly in this block is likely to lead to a retain cycleCapturing 'self' strongly in this block is likely to lead to a retain cycle
        let strongSelf: OpenHABViewController = self
        currentPageOperation?.setCompletionBlockWithSuccess({ operation, responseObject in
            os_log("Page loaded with success", log: OSLog.remoteAccess, type: .info)
            let headers = operation.response?.allHeaderFields

            if headers?["X-Atmosphere-tracking-id"] != nil {
                if let object = headers?["X-Atmosphere-tracking-id"] {
                    os_log("Found X-Atmosphere-tracking-id: %{PUBLIC}@", log: .remoteAccess, type: .info, object as! CVarArg)
                }
                // Establish the strong self reference
                strongSelf.atmosphereTrackingId = headers?["X-Atmosphere-tracking-id"] as? String ?? ""
            }
            let response = responseObject as? Data
            // If we are talking to openHAB 1.X, talk XML
            if self.appData?.openHABVersion == 1 {
                var doc: GDataXMLDocument?
                if let response = response {
                    doc = try? GDataXMLDocument(data: response)
                }
                if doc == nil {
                    return
                }
                if let name = doc?.rootElement().name() {
                    os_log("%{PUBLIC}@", log: .remoteAccess, type: .info, name)
                }
                if doc?.rootElement().name() == "page" {
                    if let rootElement = doc?.rootElement() {
                        self.currentPage = OpenHABSitemapPage(xml: rootElement)
                    }
                } else {
                    os_log("Unable to find page root element", log: .remoteAccess, type: .info)
                    return
                }
            } else {
                // Newer versions talk JSON!
                let decoder = JSONDecoder()
                if let response = response {
                    os_log("openHAB 2", log: OSLog.remoteAccess, type: .info)
                    do {
                        let sitemapPageCodingData = try decoder.decode(OpenHABSitemapPage.CodingData.self, from: response)
                        self.currentPage = sitemapPageCodingData.openHABSitemapPage
                    } catch {
                        os_log("Should not throw %{PUBLIC}@", log: OSLog.remoteAccess, type: .error, error.localizedDescription)
                    }
                }
            }
            strongSelf.currentPage?.delegate = strongSelf
            strongSelf.widgetTableView.reloadData()
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            strongSelf.refreshControl?.endRefreshing()
            strongSelf.navigationItem.title = strongSelf.currentPage?.title.components(separatedBy: "[")[0]
            if longPolling == true {
                strongSelf.loadPage(false)
            } else {
                strongSelf.loadPage(true)
            }
        }, failure: { operation, error in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            os_log("On LoadPage %{PUBLIC}@ code: %d ", log: .remoteAccess, type: .error, error.localizedDescription, Int(operation.response?.statusCode ?? 0))
            strongSelf.atmosphereTrackingId = ""
            if (error as NSError?)?.code == -1001 && longPolling {
                os_log("Timeout, restarting requests", log: OSLog.remoteAccess, type: .error)
                strongSelf.loadPage(false)
            } else if (error as NSError?)?.code == -999 {
                os_log("Request was cancelled", log: OSLog.remoteAccess, type: .error)
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
                os_log("Request failed: %{PUBLIC}@", log: .remoteAccess, type: .error, error.localizedDescription)
            }
        })
        os_log("OpenHABViewController sending new request", log: .remoteAccess, type: .error)
        currentPageOperation?.start()
        os_log("OpenHABViewController request sent", log: .remoteAccess, type: .error)
    }

    // Select sitemap
    func selectSitemap() {

        if let sitemapsUrl = Endpoint.sitemaps(openHABRootUrl: openHABRootUrl).url {
            var sitemapsRequest = URLRequest(url: sitemapsUrl)
            sitemapsRequest.setAuthCredentials(openHABUsername, openHABPassword)
            sitemapsRequest.timeoutInterval = 10.0
            let operation = OpenHABHTTPRequestOperation(request: sitemapsRequest, delegate: self)

            operation.setCompletionBlockWithSuccess({ operation, responseObject in
                let response = responseObject as? Data
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                self.sitemaps = []
                // If we are talking to openHAB 1.X, talk XML
                if self.appData?.openHABVersion == 1 {
                    if let response = response {
                        os_log("%{PUBLIC}@", log: .remoteAccess, type: .info, String(data: response, encoding: .utf8) ?? "")
                    }
                    var doc: GDataXMLDocument?
                    if let response = response {
                        doc = try? GDataXMLDocument(data: response)
                    }
                    if doc == nil {
                        return
                    }
                    if let name = doc?.rootElement().name() {
                        os_log("%{PUBLIC}@", log: .remoteAccess, type: .info, name)
                    }
                    if doc?.rootElement().name() == "sitemaps" {
                        for element in doc?.rootElement().elements(forName: "sitemap") ?? [] {
                            if let element = element as? GDataXMLElement {
                                let sitemap = OpenHABSitemap(xml: element)
                                self.sitemaps.append(sitemap)
                            }
                        }
                    }
                } else {
                    // Newer versions speak JSON!
                    let decoder = JSONDecoder()
                    if let response = response {
                        do {
                            os_log("Response will be decoded by JSON", log: .remoteAccess, type: .info)
                            let codingData = try decoder.decode([OpenHABSitemap.CodingData].self, from: response)
                            for codingDatum in codingData {
                                self.sitemaps.append(codingDatum.openHABSitemap)
                            }
                        } catch {
                            os_log("Should not throw %{PUBLIC}@", log: .remoteAccess, type: .error, error.localizedDescription)
                        }
                    }
                }
                self.appData?.sitemaps = self.sitemaps
                if !self.sitemaps.isEmpty {
                    if self.sitemaps.count > 1 {
                        if self.defaultSitemap != "" {
                            let sitemapToOpen: OpenHABSitemap? = self.sitemap(byName: self.defaultSitemap)
                            if sitemapToOpen != nil {
                                self.pageUrl = sitemapToOpen?.homepageLink ?? ""
                                self.loadPage(false)
                            } else {
                                self.performSegue(withIdentifier: "showSelectSitemap", sender: self)
                            }
                        } else {
                            self.performSegue(withIdentifier: "showSelectSitemap", sender: self)
                        }
                    } else {
                        self.pageUrl = self.sitemaps[0].homepageLink
                        self.loadPage(false)
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
                        view.configureContent(title: "Error", body: "openHAB returned empty sitemap list")
                        view.button?.setTitle("Dismiss", for: .normal)
                        view.buttonTapHandler = { _ in SwiftMessages.hide() }
                        return view
                    }
                }

            }, failure: { operation, error in
                os_log("%{PUBLIC}@ %d", log: .default, type: .error, error.localizedDescription, Int(operation.response?.statusCode ?? 0))
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
            })
            os_log("Firing request", log: .viewCycle, type: .info)

            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            operation.start()
        }
    }

    // load app settings
    func loadSettings() {
        let prefs = UserDefaults.standard
        openHABUsername = prefs.string(forKey: "username") ?? ""
        openHABPassword = prefs.string(forKey: "password") ?? ""
        defaultSitemap = prefs.string(forKey: "defaultSitemap") ?? ""
        idleOff = prefs.bool(forKey: "idleOff")
        let rawIconType = prefs.integer(forKey: "iconType")
        iconType = IconType(rawValue: rawIconType) ?? .png

        appData?.openHABUsername = openHABUsername
        appData?.openHABPassword = openHABPassword
    }

    // Set SDImage (used for widget icons and images) authentication
    func setSDImageAuth() {
        let requestModifier = SDWebImageDownloaderRequestModifier { (request) -> URLRequest? in
            let authStr = "\(self.openHABUsername):\(self.openHABPassword)"
            let authData: Data? = authStr.data(using: .ascii)
            let authValue = "Basic \(authData?.base64EncodedString(options: []) ?? "")"
            var r = request
            r.setValue(authValue, forHTTPHeaderField: "Authorization")
            return r
        }
        SDWebImageDownloader.shared.requestModifier = requestModifier

        // Setup SDWebImage to use our downloader operation which handles client certificates
        SDWebImageDownloader.shared.config.operationClass = OpenHABSDWebImageDownloaderOperation.self
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
        if pageUrl != "" {
            let pageReachability = Reachability(hostname: pageUrl)
            if !pageNetworkStatusAvailable {
                pageNetworkStatus = pageReachability?.connection
                pageNetworkStatusAvailable = true
                return false
            } else {
                if pageNetworkStatus == pageReachability?.connection {
                    return false
                } else {
                    pageNetworkStatus = pageReachability?.connection
                    return true
                }
            }
        }
        return false
    }

    // App wide data access
    // https://stackoverflow.com/questions/45832155/how-do-i-refactor-my-code-to-call-appdelegate-on-the-main-thread
    var appData: OpenHABDataObject? {
        return AppDelegate.appDelegate.appData
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
