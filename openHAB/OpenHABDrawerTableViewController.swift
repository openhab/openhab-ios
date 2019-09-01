//
//  OpenHABDrawerTableViewController.swift
//  openHAB
//
//  Created by Victor Belov on 23/05/16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import DynamicButton
import Fuzi
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
                let sitemapsCodingData = try response.decoded() as [OpenHABSitemap.CodingData]
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
    case with
    case without
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
        return AppDelegate.appDelegate.appData
    }

    init(drawerTableType: DrawerTableType?) {
        self.drawerTableType = drawerTableType
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
        if drawerTableType == .with {
            setStandardDrawerItems()
        }
        os_log("OpenHABDrawerTableViewController did load", log: .viewCycle, type: .info)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        os_log("OpenHABDrawerTableViewController viewWillAppear", log: .viewCycle, type: .info)

        if let sitemapsUrl = Endpoint.sitemaps(openHABRootUrl: openHABRootUrl).url {
            var sitemapsRequest = URLRequest(url: sitemapsUrl)
            sitemapsRequest.timeoutInterval = 10.0

            UIApplication.shared.isNetworkActivityIndicatorVisible = true

            let sitemapOperation = NetworkConnection.shared.manager.request(sitemapsRequest)
                .validate(statusCode: 200..<300)
                .responseData { (response) in
                    switch response.result {
                    case .success:
                        UIApplication.shared.isNetworkActivityIndicatorVisible = false
                        os_log("Sitemap response", log: .viewCycle, type: .info)

                        self.sitemaps = deriveSitemaps(response.result.value, version: self.appData?.openHABVersion)

                        if self.sitemaps.last?.name == "_default" {
                            self.sitemaps = Array(self.sitemaps.dropLast())
                        }

                        // Sort the sitemaps alphabetically.
                        self.sitemaps.sort { $0.name < $1.name }
                        self.drawerItems.removeAll()
                        if self.drawerTableType == .with {
                            self.setStandardDrawerItems()
                        }
                        self.tableView.reloadData()
                    case .failure(let error):
                        UIApplication.shared.isNetworkActivityIndicatorVisible = false
                        os_log("%{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
                        self.drawerItems.removeAll()
                        if self.drawerTableType == .with {
                            self.setStandardDrawerItems()
                        }
                        self.tableView.reloadData()
                    }
                }
            sitemapOperation.resume()
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
        return sitemaps.count + drawerItems.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = (tableView.dequeueReusableCell(withIdentifier: OpenHABDrawerTableViewController.tableViewCellIdentifier) as? DrawerUITableViewCell)!

        cell.customImageView.subviews.forEach { $0.removeFromSuperview() }

        if indexPath.row < sitemaps.count && !sitemaps.isEmpty {
            let imageView = UIImageView(frame: cell.customImageView.bounds)

            cell.customTextLabel?.text = sitemaps[indexPath.row].label
            if sitemaps[indexPath.row].icon != "" {
                if let iconURL = Endpoint.iconForDrawer(rootUrl: openHABRootUrl, version: appData?.openHABVersion ?? 2, icon: sitemaps[indexPath.row].icon ).url {
                    var imageRequest = URLRequest(url: iconURL)
                    imageRequest.timeoutInterval = 10.0

                    let imageOperation = NetworkConnection.shared.manager.request(imageRequest)
                        .validate(statusCode: 200..<300)
                        .responseData { (response) in
                            switch response.result {
                            case .success:
                                if let data = response.data {
                                    imageView.image = UIImage(data: data)
                                }
                            case .failure:
                                imageView.image = UIImage(named: "icon-76x76.png")
                            }
                        }
                    imageOperation.resume()
                }
            } else {
                imageView.image = UIImage(named: "icon-76x76.png")
            }
            cell.customImageView.addSubview(imageView)
        } else {
            // Then menu items
            let drawerItem = drawerItems[indexPath.row - sitemaps.count]

            cell.customTextLabel?.text = drawerItem.label

            let buttonIcon = DynamicButton(frame: cell.customImageView.bounds)
            buttonIcon.bounceButtonOnTouch = false
            buttonIcon.strokeColor = .black
            buttonIcon.lineWidth = 1

            if drawerItem.tag == "notifications" {
                buttonIcon.style = .custom(DynamicButtonStyleBell.self)

                cell.customImageView.addSubview(buttonIcon)
            } else if drawerItem.tag == "settings" {
                buttonIcon.style = .custom(DynamicButtonStyleGear.self)
                cell.customImageView.addSubview(buttonIcon)
            }
        }
        cell.separatorInset = UIEdgeInsets(top: 0, left: 60, bottom: 0, right: 0)

        cell.preservesSuperviewLayoutMargins = false
        cell.layoutMargins = .zero

        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // open a alert with an OK and cancel button
        os_log("Clicked on drawer row %d", log: .viewCycle, type: .info, indexPath.row)

        tableView.deselectRow(at: indexPath, animated: false)
        // First sitemaps
        if indexPath.row < sitemaps.count && !sitemaps.isEmpty {
            let sitemap = sitemaps[indexPath.row]
            Preferences.defaultSitemap = sitemap.name
            appData?.rootViewController?.pageUrl = ""
            switch drawerTableType {
            case .with?:
                dismiss(animated: true) {
                    self.delegate?.modalDismissed(to: .root)
                }
            case .without?:
                appData?.rootViewController?.pageUrl = ""
                navigationController?.popToRootViewController(animated: true)
            case .none:
                break
            }

        } else {
            // Then menu items
            let drawerItem = drawerItems[indexPath.row - sitemaps.count]

            if drawerItem.tag == "settings" {
                dismiss(animated: true) {
                    self.delegate?.modalDismissed(to: .settings)
                }
            } else if drawerItem.tag == "notifications" {
                dismiss(animated: true) {
                    self.delegate?.modalDismissed(to: .notifications)
                }
            }
        }
    }

    private func setStandardDrawerItems() {
        // check if we are using my.openHAB, add notifications menu item then
        // Actually this should better test whether the host of the remoteUrl is on openhab.org
        if Preferences.remoteUrl.contains("openhab.org") && !Preferences.demomode {
            let notificationsItem = OpenHABDrawerItem()
            notificationsItem.label = "Notifications"
            notificationsItem.tag = "notifications"
            drawerItems.append(notificationsItem)
        }
        // Settings always go last
        let settingsItem = OpenHABDrawerItem()
        settingsItem.label = "Settings"
        settingsItem.tag = "settings"
        drawerItems.append(settingsItem)
    }

    func loadSettings() {
        openHABUsername = Preferences.username
        openHABPassword = Preferences.password
    }
}
