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

import OpenAPIURLSession
import OpenHABCore
import os.log
import SafariServices
import SFSafeSymbols
import UIKit

let logger = Logger(subsystem: "org.openhab.app", category: "OpenHABDrawerTableViewController")

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

    private var apiactor: APIActor?

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

        Task {
            do {
                apiactor = await APIActor(username: appData!.openHABUsername, password: appData!.openHABPassword, alwaysSendBasicAuth: appData!.openHABAlwaysSendCreds, url: URL(string: appData?.openHABRootUrl ?? "")!)
                sitemaps = try await apiactor?.openHABSitemaps() ?? []
                if sitemaps.last?.name == "_default", sitemaps.count > 1 {
                    sitemaps = Array(sitemaps.dropLast())
                }
                // Sort the sitemaps according to Settings selection.
                switch SortSitemapsOrder(rawValue: Preferences.sortSitemapsby) ?? .label {
                case .label: sitemaps.sort { $0.label < $1.label }
                case .name: sitemaps.sort { $0.name < $1.name }
                }

                self.drawerItems.removeAll()
                self.setStandardDrawerItems()
                self.tableView.reloadData()
            } catch {
                os_log("Error %{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
                self.drawerItems.removeAll()
                self.setStandardDrawerItems()
                self.tableView.reloadData()
            }
        }

        Task {
            do {
                await apiactor = APIActor(username: appData!.openHABUsername, password: appData!.openHABPassword, alwaysSendBasicAuth: appData!.openHABAlwaysSendCreds, url: URL(string: appData?.openHABRootUrl ?? "")!)
                uiTiles = try await apiactor?.openHABTiles() ?? []
                os_log("ui tiles response", log: .viewCycle, type: .info)
                self.tableView.reloadData()
            } catch {
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
            1
        case 1:
            uiTiles.count
        case 2:
            sitemaps.count
        case 3:
            drawerItems.count
        default:
            0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            "Main"
        case 1:
            "Tiles"
        case 2:
            "Sitemaps"
        case 3:
            "System"
        default:
            "Unknown"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = (tableView.dequeueReusableCell(withIdentifier: OpenHABDrawerTableViewController.tableViewCellIdentifier) as? DrawerUITableViewCell)!
        cell.customImageView.subviews.forEach { $0.removeFromSuperview() }
        cell.accessoryView = nil
        switch indexPath.section {
        case 0:
            cell.customTextLabel?.text = "Home"
            cell.customImageView.image = UIImage(named: "openHABIcon")
            if let currentView = appData?.currentView {
                // if we already are on the webview, pressing this again will force a refresh
                if currentView == .webview {
                    cell.accessoryView = UIImageView(image: UIImage(named: "arrow.triangle.2.circlepath"))
                }
            }
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
                    if let iconURL = Endpoint.iconForDrawer(rootUrl: appData?.openHABRootUrl ?? "", icon: sitemaps[siteMapIndex].icon).url {
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
            switch drawerItem {
            case .notifications:
                cell.customImageView.image = UIImage(systemSymbol: .bell)
            case .settings:
                cell.customImageView.image = UIImage(systemSymbol: .gear)
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
        if let url {
            let config = SFSafariViewController.Configuration()
            config.entersReaderIfAvailable = true
            let vc = SFSafariViewController(url: url, configuration: config)
            present(vc, animated: true)
        }
    }
}
