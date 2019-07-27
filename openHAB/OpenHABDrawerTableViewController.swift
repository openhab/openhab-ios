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
import os.log
import SDWebImage
import UIKit

class OpenHABDrawerTableViewController: UITableViewController {
    var sitemaps: [OpenHABSitemap] = []
    @objc var openHABRootUrl = ""
    var openHABUsername = ""
    var openHABPassword = ""
    var cellCount: Int = 0
    var drawerItems: [OpenHABDrawerItem] = []
    weak var delegate: ModalHandler?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
        drawerItems = [OpenHABDrawerItem]()
        sitemaps = []
        loadSettings()
        setStandardDrawerItems()
        os_log("OpenHABDrawerTableViewController did load", log: .viewCycle, type: .info)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        os_log("OpenHABDrawerTableViewController viewWillAppear", log: .viewCycle, type: .info)

        if let sitemapsUrl = Endpoint.sitemaps(openHABRootUrl: openHABRootUrl).url {
            var sitemapsRequest = URLRequest(url: sitemapsUrl)
            sitemapsRequest.setAuthCredentials(openHABUsername, openHABPassword)
            sitemapsRequest.timeoutInterval = 10.0
            let operation = OpenHABHTTPRequestOperation(request: sitemapsRequest, delegate: nil)
            operation.setCompletionBlockWithSuccess({ operation, responseObject in
                let response = responseObject as? Data
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                self.sitemaps = []
                os_log("Sitemap response", log: .viewCycle, type: .info)

                // If we are talking to openHAB 1.X, talk XML
                if self.appData?.openHABVersion == 1 {
                    os_log("openHAB 1", log: .viewCycle, type: .info)

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
                                #if canImport(GDataXMLElement)
                                let sitemap = OpenHABSitemap(xml: element)
                                self.sitemaps.append(sitemap)
                                #endif
                            }
                        }
                    } else {
                        return
                    }
                } else {
                    // Newer versions speak JSON!
                    let decoder = JSONDecoder()
                    if let response = response {
                        os_log("openHAB 2", log: .viewCycle, type: .info)
                        do {
                            os_log("Response will be decoded by JSON", log: .remoteAccess, type: .info)
                            let sitemapsCodingData = try decoder.decode([OpenHABSitemap.CodingData].self, from: response)
                            for sitemapCodingDatum in sitemapsCodingData {
                                if sitemapsCodingData.count != 1 && sitemapCodingDatum.name != "_default" {
                                    os_log("Sitemap %{PUBLIC}@", log: .remoteAccess, type: .info, sitemapCodingDatum.label)
                                    self.sitemaps.append(sitemapCodingDatum.openHABSitemap)
                                }
                            }
                        } catch {
                            os_log("Should not throw %{PUBLIC}@", log: .notifications, type: .error, error.localizedDescription)
                        }
                    }
                }
                // Sort the sitemaps alphabetically.
                self.sitemaps.sort { $0.name < $1.name }
                self.appData?.sitemaps = self.sitemaps
                self.drawerItems.removeAll()
                self.setStandardDrawerItems()
                self.tableView.reloadData()
            }, failure: { operation, error in
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                os_log("%{PUBLIC}@ %d", log: .default, type: .error, error.localizedDescription, Int(operation.response?.statusCode ?? 0))
                self.drawerItems.removeAll()
                self.setStandardDrawerItems()
                self.tableView.reloadData()
            })
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            operation.start()
        }
    }

    private func setStandardDrawerItems() {
        // check if we are using my.openHAB, add notifications menu item then
        let prefs = UserDefaults.standard
        // Actually this should better test whether the host of the remoteUrl is on openhab.org
        if prefs.string(forKey: "remoteUrl")?.contains("openhab.org") ?? false && !prefs.bool(forKey: "demomode") {
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

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sitemaps.count + drawerItems.count
    }

    static let tableViewCellIdentifier = "DrawerCell"

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = (tableView.dequeueReusableCell(withIdentifier: OpenHABDrawerTableViewController.tableViewCellIdentifier) as? DrawerUITableViewCell)!

        cell.customImageView.subviews.forEach { $0.removeFromSuperview() }

        if indexPath.row < sitemaps.count && !sitemaps.isEmpty {
            cell.customTextLabel?.text = sitemaps[indexPath.row].label
            if sitemaps[indexPath.row].icon != "" {
                let iconURL = Endpoint.iconForDrawer(rootUrl: openHABRootUrl, version: appData?.openHABVersion ?? 2, icon: sitemaps[indexPath.row].icon).url

                let imageView = UIImageView(frame: cell.customImageView.bounds)
                imageView.sd_setImage(with: iconURL, placeholderImage: UIImage(named: "icon-76x76.png"), options: .imageOptionsIgnoreInvalidCertIfDefined)
                cell.customImageView.addSubview(imageView)
            } else {
                let imageView = UIImageView(frame: cell.customImageView.bounds)
                imageView.image = UIImage(named: "icon-76x76.png")
                cell.customImageView.addSubview(imageView)
            }
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
            let prefs = UserDefaults.standard
            prefs.setValue(sitemap.name, forKey: "defaultSitemap")
            appData?.rootViewController?.pageUrl = ""
            dismiss(animated: true, completion: nil)
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

    func loadSettings() {
        let prefs = UserDefaults.standard
        openHABUsername = prefs.string(forKey: "username") ?? ""
        openHABPassword = prefs.string(forKey: "password") ?? ""
    }

    // App wide data access
    var appData: OpenHABDataObject? {
        return AppDelegate.appDelegate.appData
    }

}
