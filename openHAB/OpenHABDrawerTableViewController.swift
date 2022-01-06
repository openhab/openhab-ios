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

enum DrawerTableType {
    case withStandardMenuEntries
    case withoutStandardMenuEntries
}

class OpenHABDrawerTableViewController: UITableViewController {
    static let tableViewCellIdentifier = "DrawerCell"

    var sitemaps: [OpenHABSitemap] = []
    var openHABRootUrl = ""
    var openHABUsername = ""
    var openHABPassword = ""
    var drawerItems: [OpenHABDrawerItem] = []
    weak var delegate: ModalHandler?
    var drawerTableType: DrawerTableType!

    // App wide data access
    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

    init(drawerTableType: DrawerTableType?) {
        super.init(nibName: nil, bundle: nil)
        self.drawerTableType = drawerTableType
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
        if drawerTableType == .withStandardMenuEntries {
            setStandardDrawerItems()
        }
        os_log("OpenHABDrawerTableViewController did load", log: .viewCycle, type: .info)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        os_log("OpenHABDrawerTableViewController viewWillAppear", log: .viewCycle, type: .info)

        NetworkConnection.sitemaps(openHABRootUrl: openHABRootUrl) { response in
            switch response.result {
            case .success:
                os_log("Sitemap response", log: .viewCycle, type: .info)

                self.sitemaps = deriveSitemaps(response.result.value, version: self.appData?.openHABVersion)

                if self.sitemaps.last?.name == "_default" {
                    self.sitemaps = Array(self.sitemaps.dropLast())
                }

                // Sort the sitemaps alphabetically.
                self.sitemaps.sort { $0.label < $1.label }
                self.drawerItems.removeAll()
                if self.drawerTableType == .withStandardMenuEntries {
                    self.setStandardDrawerItems()
                }
                self.tableView.reloadData()
            case let .failure(error):
                os_log("%{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
                self.drawerItems.removeAll()
                if self.drawerTableType == .withStandardMenuEntries {
                    self.setStandardDrawerItems()
                }
                self.tableView.reloadData()
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

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sitemaps.count + drawerItems.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = (tableView.dequeueReusableCell(withIdentifier: OpenHABDrawerTableViewController.tableViewCellIdentifier) as? DrawerUITableViewCell)!

        cell.customImageView.subviews.forEach { $0.removeFromSuperview() }

        if indexPath.row < sitemaps.count, !sitemaps.isEmpty {
            let imageView = UIImageView(frame: cell.customImageView.bounds)

            cell.customTextLabel?.text = sitemaps[indexPath.row].label
            if !sitemaps[indexPath.row].icon.isEmpty {
                if let iconURL = Endpoint.iconForDrawer(rootUrl: openHABRootUrl, version: appData?.openHABVersion ?? 2, icon: sitemaps[indexPath.row].icon).url {
                    imageView.kf.setImage(
                        with: iconURL,
                        placeholder: UIImage(named: "openHABIcon")
                    )
                }
            } else {
                imageView.image = UIImage(named: "openHABIcon")
            }
            cell.customImageView.image = imageView.image
        } else {
            // Then menu items
            let drawerItem = drawerItems[indexPath.row - sitemaps.count]

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
        os_log("Clicked on drawer row %d", log: .viewCycle, type: .info, indexPath.row)

        tableView.deselectRow(at: indexPath, animated: false)
        // First sitemaps
        if indexPath.row < sitemaps.count, !sitemaps.isEmpty {
            let sitemap = sitemaps[indexPath.row]
            Preferences.defaultSitemap = sitemap.name
            appData?.rootViewController?.pageUrl = ""
            switch drawerTableType {
            case .withStandardMenuEntries?:
                dismiss(animated: true) {
                    self.delegate?.modalDismissed(to: .root)
                }
            case .withoutStandardMenuEntries?:
                navigationController?.popToRootViewController(animated: true)
            case .none:
                break
            }

        } else {
            // Then menu items
            let drawerItem = drawerItems[indexPath.row - sitemaps.count]

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
}
