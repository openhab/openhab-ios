// Copyright (c) 2010-2022 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import DynamicButton
import Fuzi
import OpenHABCore
import os.log
import SafariServices
import UIKit

func deriveSitemaps(_ response: Data?, version: Int?) -> [OpenHABSitemap] {
    var sitemaps = [OpenHABSitemap]()

    // If we are talking to openHAB 1.X, talk XML
    if version == 1 {
        os_log("openHAB 1", log: .viewCycle, type: .info)

        if let response = response {
            os_log("%{PUBLIC}@", log: .remoteAccess, type: .info, String(data: response, encoding: .utf8) ?? "")
        }
        if let data = response,
           let doc = try? XMLDocument(data: data),
           let name = doc.root?.tag {
            os_log("%{PUBLIC}@", log: .remoteAccess, type: .info, name)
            if name == "sitemaps" {
                for element in doc.root?.children(tag: "sitemap") ?? [] {
                    let sitemap = OpenHABSitemap(xml: element)
                    sitemaps.append(sitemap)
                }
            }
        } else {
            return []
        }
    } else {
        // Newer versions speak JSON!
        if let response = response {
            os_log("openHAB 2", log: .viewCycle, type: .info)
            do {
                os_log("Response will be decoded by JSON", log: .remoteAccess, type: .info)
                let sitemapsCodingData = try response.decoded(as: [OpenHABSitemap.CodingData].self)
                for sitemapCodingDatum in sitemapsCodingData {
                    os_log("Sitemap %{PUBLIC}@", log: .remoteAccess, type: .info, sitemapCodingDatum.label)
                    sitemaps.append(sitemapCodingDatum.openHABSitemap)
                }
            } catch {
                os_log("Should not throw %{PUBLIC}@", log: .notifications, type: .error, error.localizedDescription)
            }
        }
    }
    return sitemaps
}

struct UiTile: Decodable {
    var name: String
    var url: String
    var imageUrl: String
}

class OpenHABDrawerTableViewController: UITableViewController {
    static let tableViewCellIdentifier = "DrawerCell"

    var sitemaps: [OpenHABSitemap] = []
    var uiTiles: [OpenHABUiTile] = []
    var openHABUsername = ""
    var openHABPassword = ""
    var drawerItems: [OpenHABDrawerItem] = []
    weak var delegate: ModalHandler?

    // App wide data access
    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
        drawerItems = []
        sitemaps = []
        loadSettings()
        setStandardDrawerItems()
        os_log("OpenHABDrawerTableViewController did load", log: .viewCycle, type: .info)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        os_log("OpenHABDrawerTableViewController viewWillAppear", log: .viewCycle, type: .info)

        NetworkConnection.sitemaps(openHABRootUrl: appData?.openHABRootUrl ?? "") { response in
            switch response.result {
            case let .success(data):
                os_log("Sitemap response", log: .viewCycle, type: .info)

                self.sitemaps = deriveSitemaps(data, version: self.appData?.openHABVersion)

                if self.sitemaps.last?.name == "_default", self.sitemaps.count > 1 {
                    self.sitemaps = Array(self.sitemaps.dropLast())
                }

                // Sort the sitemaps according to Settings selection.
                switch SortSitemapsOrder(rawValue: Preferences.sortSitemapsby) ?? .label {
                case .label: self.sitemaps.sort { $0.label < $1.label }
                case .name: self.sitemaps.sort { $0.name < $1.name }
                }

                self.drawerItems.removeAll()
                self.setStandardDrawerItems()
                self.tableView.reloadData()
            case let .failure(error):
                os_log("%{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
                self.drawerItems.removeAll()
                self.setStandardDrawerItems()
                self.tableView.reloadData()
            }
        }

        NetworkConnection.uiTiles(openHABRootUrl: appData?.openHABRootUrl ?? "") { response in
            switch response.result {
            case .success:
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                os_log("ui tiles response", log: .viewCycle, type: .info)
                guard let responseData = response.data else {
                    os_log("Error: did not receive data", log: OSLog.remoteAccess, type: .info)
                    return
                }
                do {
                    self.uiTiles = try JSONDecoder().decode([OpenHABUiTile].self, from: responseData)
                    self.tableView.reloadData()
                } catch {
                    os_log("Error: did not receive data %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, error.localizedDescription)
                }
            case let .failure(error):
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                os_log("%{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.reloadData()
        os_log("RightDrawerViewController viewDidAppear", log: .viewCycle, type: .info)
        os_log("Sitemap count: %d", log: .viewCycle, type: .info, Int(sitemaps.count))
        os_log("Menu items count: %d", log: .viewCycle, type: .info, Int(drawerItems.count))
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated) // Call the super class implementation.
        os_log("RightDrawerViewController viewDidDisappear", log: .viewCycle, type: .info)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        4
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return uiTiles.count
        case 2:
            return sitemaps.count
        case 3:
            return drawerItems.count
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Main"
        case 1:
            return "Tiles"
        case 2:
            return "Sitemaps"
        case 3:
            return "System"
        default:
            return "Unknown"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = (tableView.dequeueReusableCell(withIdentifier: OpenHABDrawerTableViewController.tableViewCellIdentifier) as? DrawerUITableViewCell)!
        cell.customImageView.subviews.forEach { $0.removeFromSuperview() }
        switch indexPath.section {
        case 0:
            cell.customTextLabel?.text = "Home"
            cell.customImageView.image = UIImage(named: "openHABIcon")
        case 1:
            let imageView = UIImageView(frame: cell.customImageView.bounds)
            let tile = uiTiles[indexPath.row]
            cell.customTextLabel?.text = tile.name
            let passedURL = tile.imageUrl
            // Dependent on $OPENHAB_CONF/services/runtime.cfg
            // Can either be an absolute URL, a path (sometimes malformed) or the content to be displayed (for imageURL)
            if !passedURL.isEmpty {
                switch passedURL {
                case _ where passedURL.hasPrefix("data:image"):
                    if let imageData = Data(base64Encoded: passedURL.deletingPrefix("data:image/png;base64,"), options: .ignoreUnknownCharacters) {
                        imageView.image = UIImage(data: imageData)
                    } // data;image/png;base64,
                case _ where passedURL.hasPrefix("http"):
                    os_log("Loading %{PUBLIC}@", log: .default, type: .info, String(describing: passedURL))
                    imageView.kf.setImage(with: URL(string: passedURL), placeholder: UIImage(named: "openHABIcon"))
                default:
                    if let builtURL = Endpoint.resource(openHABRootUrl: appData?.openHABRootUrl ?? "", path: passedURL.prepare()).url {
                        os_log("Loading %{PUBLIC}@", log: .default, type: .info, String(describing: builtURL))
                        imageView.kf.setImage(with: builtURL, placeholder: UIImage(named: "openHABIcon"))
                    }
                }
            } else {
                imageView.image = UIImage(named: "openHABIcon")
            }
            cell.customImageView.image = imageView.image
        case 2:
            if !sitemaps.isEmpty {
                let siteMapIndex = indexPath.row
                let imageView = UIImageView(frame: cell.customImageView.bounds)

                cell.customTextLabel?.text = sitemaps[siteMapIndex].label
                if !sitemaps[siteMapIndex].icon.isEmpty {
                    if let iconURL = Endpoint.iconForDrawer(rootUrl: appData?.openHABRootUrl ?? "", version: appData?.openHABVersion ?? 2, icon: sitemaps[siteMapIndex].icon).url {
                        imageView.kf.setImage(with: iconURL, placeholder: UIImage(named: "openHABIcon"))
                    }
                } else {
                    imageView.image = UIImage(named: "openHABIcon")
                }
                cell.customImageView.image = imageView.image
            }
        case 3:
            // Then menu items
            let drawerItem = drawerItems[indexPath.row]

            cell.customTextLabel?.text = drawerItem.localizedString

            if #available(iOS 13, *) {
                switch drawerItem {
                case .notifications:
                    cell.customImageView.image = UIImage(systemName: "bell")
                case .settings:
                    cell.customImageView.image = UIImage(systemName: "gear")
                }
            } else {
                let buttonIcon = DynamicButton(frame: cell.customImageView.bounds)
                buttonIcon.bounceButtonOnTouch = false

                buttonIcon.strokeColor = .black
                buttonIcon.lineWidth = 1

                switch drawerItem {
                case .notifications:
                    buttonIcon.style = .custom(DynamicButtonStyleBell.self)
                case .settings:
                    buttonIcon.style = .custom(DynamicButtonStyleGear.self)
                }
                cell.customImageView.addSubview(buttonIcon)
            }
        default:
            break
        }
        cell.separatorInset = UIEdgeInsets(top: 0, left: 60, bottom: 0, right: 0)

        cell.preservesSuperviewLayoutMargins = false
        cell.layoutMargins = .zero

        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        44
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // open a alert with an OK and cancel button
        os_log("Clicked on drawer section %d row %d", log: .viewCycle, type: .info, indexPath.section, indexPath.row)

        tableView.deselectRow(at: indexPath, animated: false)
        // First sitemaps
        switch indexPath.section {
        case 0:
            dismiss(animated: true) {
                self.delegate?.modalDismissed(to: .webview)
            }
        case 1:
            let passedURL = uiTiles[indexPath.row].url
            // Dependent on $OPENHAB_CONF/services/runtime.cfg
            // Can either be an absolute URL, a path (sometimes malformed)
            if !passedURL.isEmpty {
                switch passedURL {
                case _ where passedURL.hasPrefix("http"):
                    openURL(url: URL(string: passedURL))
                default:
                    let builtURL = Endpoint.resource(openHABRootUrl: appData?.openHABRootUrl ?? "", path: passedURL.prepare())
                    openURL(url: builtURL.url)
                }
            }
        case 2:
            if !sitemaps.isEmpty {
                let sitemap = sitemaps[indexPath.row]
                Preferences.defaultSitemap = sitemap.name
                appData?.sitemapViewController?.pageUrl = ""
                dismiss(animated: true) {
                    os_log("self delegate %d", log: .viewCycle, type: .info, self.delegate != nil)
                    self.delegate?.modalDismissed(to: .sitemap)
                }
            }
        case 3:
            // Then menu items
            let drawerItem = drawerItems[indexPath.row]

            switch drawerItem {
            case .settings:
                dismiss(animated: true) {
                    self.delegate?.modalDismissed(to: .settings)
                }
            case .notifications:
                dismiss(animated: true) {
                    self.delegate?.modalDismissed(to: .notifications)
                }
            }
        default:
            break
        }
    }

    private func setStandardDrawerItems() {
        // check if we are using my.openHAB, add notifications menu item then
        // Actually this should better test whether the host of the remoteUrl is on openhab.org
        if Preferences.remoteUrl.contains("openhab.org"), !Preferences.demomode {
            drawerItems.append(.notifications)
        }
        // Settings always go last
        drawerItems.append(.settings)
    }

    func loadSettings() {
        openHABUsername = Preferences.username
        openHABPassword = Preferences.password
    }

    private func openURL(url: URL?) {
        if let url = url {
            let config = SFSafariViewController.Configuration()
            config.entersReaderIfAvailable = true
            let vc = SFSafariViewController(url: url, configuration: config)
            present(vc, animated: true)
        }
    }
}
