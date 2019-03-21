//
//  OpenHABViewController.swift
//  openHAB
//
//  Created by Victor Belov on 12/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import SDWebImage
import UIKit
import AVKit
import AVFoundation

let manager: SDWebImageDownloader? = SDWebImageManager.shared().imageDownloader

private let OpenHABViewControllerMapViewCellReuseIdentifier = "OpenHABViewControllerMapViewCellReuseIdentifier"
private let OpenHABViewControllerImageViewCellReuseIdentifier = "OpenHABViewControllerImageViewCellReuseIdentifier"

class OpenHABViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, OpenHABTrackerDelegate, OpenHABSitemapPageDelegate, OpenHABSelectionTableViewControllerDelegate, ColorPickerUITableViewCellDelegate, AFRememberingSecurityPolicyDelegate, ClientCertificateManagerDelegate {

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

    func openHABTracked(_ openHABUrl: String?) {
        print("OpenHABViewController openHAB URL = \(openHABUrl ?? "")")
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        openHABRootUrl = openHABUrl ?? ""
        appData()?.openHABRootUrl = openHABRootUrl

        // Checking openHAB version
        var components = URLComponents(string: openHABRootUrl)
        components?.path = "/rest/bindings"
        if let pageToLoadUrl = components?.url {
            var pageRequest = URLRequest(url: pageToLoadUrl)

            pageRequest.setAuthCredentials(openHABUsername, openHABPassword)
            pageRequest.timeoutInterval = 10.0
            let versionPageOperation = OpenHABHTTPRequestOperation(request: pageRequest, delegate: self)

            versionPageOperation.setCompletionBlockWithSuccess({ operation, responseObject in
                print("This is an openHAB 2.X")
                self.appData()?.openHABVersion = 2
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                self.selectSitemap()
            }, failure: { operation, error in
                print("This is an openHAB 1.X")
                self.appData()?.openHABVersion = 1
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                print("Error:------On Tracking>\(error.localizedDescription)")
                print(String(format: "error code %ld", Int(operation.response?.statusCode ?? 0)))
                self.selectSitemap()
            })
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
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
                print("Command sent!")
            }, failure: { operation, error in
                print("Error:------>\(error.localizedDescription )")
                print(String(format: "error code %ld", Int(operation.response?.statusCode ?? 0)))
            })
            print("Timeout \(commandRequest.timeoutInterval)")
            if let link = item?.link {
                print("OpenHABViewController posting \(command ?? "") command to \(link)")
                print(commandRequest.debugDescription)
            }
            commandOperation?.start()
        }
    }

    // Here goes everything about view loading, appearing, disappearing, entering background and becoming active
    override func viewDidLoad() {
        super.viewDidLoad()
        print("OpenHABViewController viewDidLoad")
        pageNetworkStatus = nil //NetworkStatus(rawValue: -1)
        sitemaps = []
        widgetTableView.tableFooterView = UIView()
        NotificationCenter.default.addObserver(self, selector: #selector(OpenHABViewController.didEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(OpenHABViewController.didBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)

        self.registerTableViewCells()
        self.configureTableView()

        refreshControl = UIRefreshControl()
        refreshControl?.backgroundColor = UIColor.groupTableViewBackground
        //    self.refreshControl.tintColor = [UIColor whiteColor];
        refreshControl?.addTarget(self, action: #selector(OpenHABViewController.handleRefresh(_:)), for: .valueChanged)
        if let refreshControl = refreshControl {
            widgetTableView.addSubview(refreshControl)
        }
        if let refreshControl = refreshControl {
            widgetTableView.sendSubviewToBack(refreshControl)
        }

        let rightDrawerButton = MMDrawerBarButtonItem(target: self, action: #selector(OpenHABViewController.rightDrawerButtonPress(_:)))
        navigationItem.setRightBarButton(rightDrawerButton, animated: true)
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
        //    [self.widgetTableView reloadData];
        //    [self.widgetTableView layoutIfNeeded];
    }

    @objc func handleApsRegistration(_ note: Notification?) {
        print("handleApsRegistration")
        let theData = note?.userInfo
        if theData != nil {
            deviceId = theData?["deviceId"] as? String ?? ""
            deviceToken = theData?["deviceToken"] as? String ?? ""
            deviceName = theData?["deviceName"] as? String ?? ""
            doRegisterAps()
        }
    }

    @objc func rightDrawerButtonPress(_ sender: Any?) {
        let drawer = mm_drawerController.rightDrawerViewController as? OpenHABDrawerTableViewController
        drawer?.openHABRootUrl = openHABRootUrl
        mm_drawerController.toggle(MMDrawerSide.right, animated: true, completion: nil)
    }

    func doRegisterAps() {
        if let prefsURL = UserDefaults.standard.value(forKey: "remoteUrl") as? String, prefsURL.contains("openhab.org") {
            if deviceId != "" && deviceToken != "" && deviceName != "" {
                print("Registering notifications with \(prefsURL)")

                if let registrationUrl = Endpoint.appleRegistration(prefsURL: prefsURL, deviceToken: deviceToken, deviceId: deviceId, deviceName: deviceName).url {
                    var registrationRequest = URLRequest(url: registrationUrl)

                    print("Registration URL = \(registrationUrl.absoluteString)")
                    registrationRequest.setAuthCredentials(openHABUsername, openHABPassword)
                    let registrationOperation = OpenHABHTTPRequestOperation(request: registrationRequest, delegate: self)
                    registrationOperation.setCompletionBlockWithSuccess({ operation, responseObject in
                        print("my.openHAB registration sent")
                    }, failure: { operation, error in
                        print("my.openHAB registration failed")
                        print("Error:------>\(error.localizedDescription)")
                        print(String(format: "error code %ld", Int(operation.response?.statusCode ?? 0)))
                    })
                    registrationOperation.start()
                }
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        print("OpenHABViewController viewDidAppear")
        super.viewDidAppear(animated)
        widgetTableView.reloadData() // reloading data for the first tableView serves another purpose, not exactly related to this question.
        widgetTableView.setNeedsLayout()
        widgetTableView.layoutIfNeeded()
        widgetTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        print("OpenHABViewController viewWillAppear")
        super.viewDidAppear(animated)
        // Load settings into local properties
        loadSettings()
        // Set authentication parameters to SDImag
        setSDImageAuth()
        // Set default controller for TSMessage to self
        TSMessage.setDefaultViewController(navigationController)
        // Disable idle timeout if configured in settings
        if idleOff {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        doRegisterAps()
        // if pageUrl == "" it means we are the first opened OpenHABViewController
        if pageUrl == "" {
            // Set self as root view controller
            appData()?.rootViewController = self
            // Add self as observer for APS registration
            NotificationCenter.default.addObserver(self, selector: #selector(OpenHABViewController.handleApsRegistration(_:)), name: NSNotification.Name("apsRegistered"), object: nil)
            if currentPage != nil {
                currentPage?.widgets = []
                widgetTableView.reloadData()
            }
            print("OpenHABViewController pageUrl is empty, this is first launch")
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            tracker = OpenHABTracker()
            tracker?.delegate = self
            tracker?.start()
        } else {
            if !pageNetworkStatusChanged() {
                print("OpenHABViewController pageUrl = \(pageUrl), loading page")
                loadPage(false)
            } else {
                print("OpenHABViewController network status changed while I was not appearing")
                restart()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        print("OpenHABViewController viewWillDisappear")
        if currentPageOperation != nil {
            currentPageOperation?.cancel()
            currentPageOperation = nil
        }
        super.viewWillDisappear(animated)
    }

    @objc func didEnterBackground(_ notification: Notification?) {
        print("OpenHABViewController didEnterBackground")
        if currentPageOperation != nil {
            currentPageOperation?.cancel()
            currentPageOperation = nil
        }
        UIApplication.shared.isIdleTimerDisabled = false
    }

    @objc func didBecomeActive(_ notification: Notification?) {
        print("OpenHABViewController didBecomeActive")
        // re disable idle off timer
        if idleOff {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        if isViewLoaded && view.window != nil && pageUrl != "" {
            if !pageNetworkStatusChanged() {
                print("OpenHABViewController isViewLoaded, restarting network activity")
                loadPage(false)
            } else {
                print("OpenHABViewController network status changed while it was inactive")
                restart()
            }
        }
    }

    func restart() {
        if appData()?.rootViewController == self {
            print("I am a rootViewController!")
        } else {
            appData()?.rootViewController?.pageUrl = ""
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
                print("Webview/Mapview height would be \(heightValue)")
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
        case "Chart":
            cell = tableView.dequeueReusableCell(for: indexPath) as NewImageUITableViewCell
        case "Image":
            cell=tableView.dequeueReusableCell(withIdentifier: "OpenHABViewControllerImageViewCellReuseIdentifier", for: indexPath)  as! NewImageUITableViewCell
        case "Video":
            cell=tableView.dequeueReusableCell(withIdentifier: "VideoUITableViewCell", for: indexPath)  as! VideoUITableViewCell
        case "Webview":
            cell = tableView.dequeueReusableCell(for: indexPath) as WebUITableViewCell
        case "Mapview":
            cell = (tableView.dequeueReusableCell(withIdentifier: OpenHABViewControllerMapViewCellReuseIdentifier) as? MapViewTableViewCell)!
        default:
            cell = tableView.dequeueReusableCell(for: indexPath) as GenericUITableViewCell
        }

        // No icon is needed for image, video, frame and web widgets
        if (widget?.icon != nil) && !( (cell is NewImageUITableViewCell) || (cell is VideoUITableViewCell) || (cell is FrameUITableViewCell) || (cell is WebUITableViewCell) ) {

            var components = URLComponents(string: openHABRootUrl)

            if appData()?.openHABVersion == 2 {
                if let icon = widget?.icon {
                    components?.path = "/icon/\(icon)"
                    components?.queryItems = [
                        URLQueryItem(name: "state", value: widget?.item?.state )
                    ]
                }
            } else {
                if let icon = widget?.icon {
                    components?.path = "/images/\(icon).png"
                }
            }

            let urlc = components?.url ?? URL(string: "")
            cell.imageView?.sd_setImage(with: urlc, placeholderImage: UIImage(named: "blankicon.png"), options: [])

        }

        if let cell = cell as? NewImageUITableViewCell {

            func createImageURL(with urlString: String) -> URL {
                let random = Int.random(in: 0..<1000)
                var components = URLComponents(string: urlString)
                components?.queryItems?.append(contentsOf: [
                    URLQueryItem(name: "random", value: String(random))
                    ])
                return components?.url ?? URL(string: "")!
            }

            func createChartURL(with baseUrl: String) -> URL {
                let random = Int.random(in: 0..<1000)
                var components = URLComponents(string: baseUrl)
                components?.path = "/api"
                components?.queryItems = [
                    URLQueryItem(name: "period", value: widget!.period),
                    URLQueryItem(name: "random", value: String(random))
                ]

                if (widget?.item?.type == "GroupItem") || (widget?.item?.type == "Group") {
                    components?.queryItems?.append(URLQueryItem(name: "groups", value: widget?.item?.name))
                } else {
                    components?.queryItems?.append(URLQueryItem(name: "items", value: widget?.item?.name))
                }
                if widget?.service != "" && (widget?.service.count)! > 0 {
                    components?.queryItems?.append(URLQueryItem(name: "service", value: widget?.service))
                }
                return components?.url ?? URL(string: "")!
            }

            let createdURL: URL
            switch widget?.type {
            case "Chart":
                print("Setting cell base url to \(openHABRootUrl)")
                createdURL = createChartURL(with: openHABRootUrl)
            case "Image":
                createdURL = createImageURL(with: widget?.url ?? "")
            default:
                createdURL = URL(string: "")!
            }

            cell.mainImageView.sd_setImage(with: createdURL, placeholderImage: UIImage(named: "blankicon.png"), options: []) { (image, error, cacheType, imageURL) in
                widget?.image = image
                cell.layoutIfNeeded()
            }
            cell.layoutIfNeeded()
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
        if cell.responds(to: #selector(setter: UITableViewCell.preservesSuperviewLayoutMargins)) {
            cell.preservesSuperviewLayoutMargins = false
        }

        // Explictly set your cell's layout margins
        if cell.responds(to: #selector(setter: UITableViewCell.layoutMargins)) {
            cell.layoutMargins = .zero
        }

        guard let videoCell = (cell as? VideoUITableViewCell) else { return }
        videoCell.playerView.player?.play()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let widget: OpenHABWidget? = currentPage?.widgets[indexPath.row]
        if widget?.linkedPage != nil {
            if let link = widget?.linkedPage?.link {
                print("Selected \(link)")
            }
            selectedWidgetRow = indexPath.row
            let newViewController = storyboard?.instantiateViewController(withIdentifier: "OpenHABPageViewController") as? OpenHABViewController
            newViewController?.pageUrl = widget?.linkedPage?.link ?? ""
            newViewController?.openHABRootUrl = openHABRootUrl
            if let newViewController = newViewController {
                navigationController?.pushViewController(newViewController, animated: true)
            }
        } else if widget?.type == "Selection" {
            print("Selected selection widget")
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
        if let cell = cell, let indexPath = widgetTableView.indexPath(for: cell) {
            widgetTableView.reloadRows(at: [indexPath], with: .none)
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
        print("OpenHABViewController prepareForSegue \(segue.identifier ?? "")")
        if segue.identifier?.isEqual("showPage") ?? false {
            let newViewController = segue.destination as? OpenHABViewController
            let selectedWidget: OpenHABWidget? = currentPage?.widgets[selectedWidgetRow]
            newViewController?.pageUrl = selectedWidget?.linkedPage?.link ?? ""
            newViewController?.openHABRootUrl = openHABRootUrl
        } else if segue.identifier?.isEqual("showSelectionView") ?? false {
            print("Selection seague")
        }
    }

    // OpenHABTracker delegate methods
    func openHABTrackingProgress(_ message: String?) {
        print("OpenHABViewController \(message ?? "")")
        TSMessage.showNotification(in: navigationController, title: "Connecting", subtitle: message, image: nil, type: TSMessageNotificationType.message, duration: 3.0, callback: nil, buttonTitle: nil, buttonCallback: nil, at: TSMessageNotificationPosition.bottom, canBeDismissedByUser: true)
    }

    func openHABTrackingError(_ error: Error) throws {
        print("OpenHABViewController discovery error")
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        TSMessage.showNotification(in: navigationController, title: "Error", subtitle: error.localizedDescription, image: nil, type: TSMessageNotificationType.error, duration: 60.0, callback: nil, buttonTitle: nil, buttonCallback: nil, at: TSMessageNotificationPosition.bottom, canBeDismissedByUser: true)
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
        print("pageUrl = \(pageUrl)")
        // If this is the first request to the page make a bulk call to pageNetworkStatusChanged
        // to save current reachability status.
        if !longPolling {
            _ = pageNetworkStatusChanged()
        }
        let pageToLoadUrl = URL(string: pageUrl)
        if let pageToLoadUrl = pageToLoadUrl {
            var pageRequest = URLRequest(url: pageToLoadUrl)

            pageRequest.setAuthCredentials(openHABUsername, openHABPassword)
            // We accept XML only if openHAB is 1.X
            if appData()?.openHABVersion == 1 {
                pageRequest.setValue("application/xml", forHTTPHeaderField: "Accept")
            }
            pageRequest.setValue("1.0", forHTTPHeaderField: "X-Atmosphere-Framework")
            if longPolling {
                print("long polling, so setting atmosphere transport")
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

            // If we are talking to openHAB 2+, we expect response to be JSON
            if appData()?.openHABVersion == 2 {
                print("Setting serializer to JSON")
                //currentPageOperation?.responseSerializer = AFJSONResponseSerializer()
            }
            // FIX Capturing 'self' strongly in this block is likely to lead to a retain cycleCapturing 'self' strongly in this block is likely to lead to a retain cycle
            let strongSelf: OpenHABViewController = self
            currentPageOperation?.setCompletionBlockWithSuccess({ operation, responseObject in
                print("Page loaded with success")
                let headers = operation.response?.allHeaderFields

                if headers?["X-Atmosphere-tracking-id"] != nil {
                    if let object = headers?["X-Atmosphere-tracking-id"] {
                        print("Found X-Atmosphere-tracking-id: \(object)")
                    }
                    // Establish the strong self reference
                    strongSelf.atmosphereTrackingId = headers?["X-Atmosphere-tracking-id"] as? String ?? ""
                }
                let response = responseObject as? Data
                // If we are talking to openHAB 1.X, talk XML
                if self.appData()?.openHABVersion == 1 {
                    var doc: GDataXMLDocument?
                    if let response = response {
                        doc = try? GDataXMLDocument(data: response)
                    }
                    if doc == nil {
                        return
                    }
                    if let name = doc?.rootElement().name() {
                        print("\(name)")
                    }
                    if doc?.rootElement().name() == "page" {
                        if let rootElement = doc?.rootElement() {
                            self.currentPage = OpenHABSitemapPage(xml: rootElement)
                        }
                    } else {
                        print("Unable to find page root element")
                        return
                    }
                } else {
                    // Newer versions talk JSON!
                    //self.currentPage = OpenHABSitemapPage(dictionary: responseObject as! [String: Any] )
                    let decoder = JSONDecoder()
                    if let response = response {
                        print("openHAB 2")
                        do {
                            let sitemapPageCodingData = try decoder.decode(OpenHABSitemapPage.CodingData.self, from: response)
                            self.currentPage = sitemapPageCodingData.openHABSitemapPage
                        } catch {
                            print("Should not throw \(error)")
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
                print("Error:------> on LoadPage \(error.localizedDescription )")
                print(String(format: "error code %ld", Int(operation.response?.statusCode ?? 0)))
                strongSelf.atmosphereTrackingId = ""
                if (error as NSError?)?.code == -1001 && longPolling {
                    print("Timeout, restarting requests")
                    strongSelf.loadPage(false)
                } else if (error as NSError?)?.code == -999 {
                    // Request was cancelled
                    print("Request was cancelled")
                } else {
                    // Error
                    if (error as NSError?)?.code == -1012 {
                        TSMessage.showNotification(in: strongSelf.navigationController, title: "Error", subtitle: "SSL Certificate Error", image: nil, type: TSMessageNotificationType.error, duration: 5.0, callback: nil, buttonTitle: nil, buttonCallback: nil, at: TSMessageNotificationPosition.bottom, canBeDismissedByUser: true)
                    } else {
                        TSMessage.showNotification(in: strongSelf.navigationController, title: "Error", subtitle: error.localizedDescription, image: nil, type: TSMessageNotificationType.error, duration: 5.0, callback: nil, buttonTitle: nil, buttonCallback: nil, at: TSMessageNotificationPosition.bottom, canBeDismissedByUser: true)
                    }
                    print("Request failed: \(error.localizedDescription)")
                }
            })
            print("OpenHABViewController sending new request")
            currentPageOperation?.start()
            print("OpenHABViewController request sent")
        }}

    // Select sitemap
    func selectSitemap() {

        var components = URLComponents(string: openHABRootUrl)
        components?.path = "/rest/sitemaps"
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "20")
        ]
        if let sitemapsUrl = components?.url {
            var sitemapsRequest = URLRequest(url: sitemapsUrl)
            sitemapsRequest.setAuthCredentials(openHABUsername, openHABPassword)
            sitemapsRequest.timeoutInterval = 10.0
            let operation = OpenHABHTTPRequestOperation(request: sitemapsRequest, delegate: self)

            operation.setCompletionBlockWithSuccess({ operation, responseObject in
                let response = responseObject as? Data
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                self.sitemaps = []
                // If we are talking to openHAB 1.X, talk XML
                if self.appData()?.openHABVersion == 1 {
                    if let response = response {
                        print("\(String(data: response, encoding: .utf8) ?? "")")
                    }
                    var doc: GDataXMLDocument?
                    if let response = response {
                        doc = try? GDataXMLDocument(data: response)
                    }
                    if doc == nil {
                        return
                    }
                    if let name = doc?.rootElement().name() {
                        print("\(name)")
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
                            print ("Response will be decoded by JSON")
                            let codingData = try decoder.decode([OpenHABSitemap.CodingData].self, from: response)
                            for codingDatum in codingData {
                                self.sitemaps.append(codingDatum.openHABSitemap)
                            }
                        } catch {
                            print("Should not throw \(error)")
                        }
                    }
                }
                self.appData()?.sitemaps = self.sitemaps
                if self.sitemaps.count > 0 {
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
                    TSMessage.showNotification(in: self.navigationController, title: "Error", subtitle: "openHAB returned empty sitemap list", image: nil, type: TSMessageNotificationType.error, duration: 5.0, callback: nil, buttonTitle: nil, buttonCallback: nil, at: TSMessageNotificationPosition.bottom, canBeDismissedByUser: true)
                }

            }, failure: { operation, error in
                print("Error:------SelectSitemap>\(error.localizedDescription)")
                print(String(format: "error code %ld", Int(operation.response?.statusCode ?? 0)))
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                // Error
                if (error as NSError?)?.code == -1012 {
                    TSMessage.showNotification(in: self.navigationController, title: "Error", subtitle: "SSL Certificate Error", image: nil, type: TSMessageNotificationType.error, duration: 5.0, callback: nil, buttonTitle: nil, buttonCallback: nil, at: TSMessageNotificationPosition.bottom, canBeDismissedByUser: true)
                } else {
                    TSMessage.showNotification(in: self.navigationController, title: "Error", subtitle: error.localizedDescription, image: nil, type: TSMessageNotificationType.error, duration: 5.0, callback: nil, buttonTitle: nil, buttonCallback: nil, at: TSMessageNotificationPosition.bottom, canBeDismissedByUser: true)
                }
            })
            print("Firing request")
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            operation .start()
        }
    }

    // load app settings
    func loadSettings() {
        let prefs = UserDefaults.standard
        openHABUsername = prefs.value(forKey: "username") as? String ?? ""
        openHABPassword = prefs.value(forKey: "password") as? String ?? ""
        defaultSitemap = prefs.value(forKey: "defaultSitemap") as? String ?? ""
        idleOff = prefs.bool(forKey: "idleOff")
        appData()?.openHABUsername = openHABUsername
        appData()?.openHABPassword = openHABPassword
    }

    // Set SDImage (used for widget icons and images) authentication
    func setSDImageAuth() {
        let authStr = "\(openHABUsername):\(openHABPassword)"
        let authData: Data? = authStr.data(using: .ascii)
        let authValue = "Basic \(authData?.base64EncodedString(options: []) ?? "")"
        // let manager: SDWebImageDownloader? = SDWebImageManager.shared().imageDownloader
        manager?.setValue(authValue, forHTTPHeaderField: "Authorization")
    }

    // Find and return sitemap by it's name if any
    func sitemap(byName sitemapName: String?) -> OpenHABSitemap? {
        for sitemap in sitemaps where sitemap.name == sitemapName {
            return sitemap
        }
        return nil
    }

    func pageNetworkStatusChanged() -> Bool {
        print("OpenHABViewController pageNetworkStatusChange")
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
    func appData() -> OpenHABDataObject? {
        let theDelegate = UIApplication.shared.delegate as? AppDelegate
        return theDelegate?.appData
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
