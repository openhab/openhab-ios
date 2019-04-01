//
//  OpenHABDrawerTableViewController.swift
//  openHAB
//
//  Created by Victor Belov on 23/05/16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import SDWebImage
import UIKit
import os.log

class OpenHABDrawerTableViewController: UITableViewController {
    var sitemaps: [OpenHABSitemap] = []
    @objc var openHABRootUrl = ""
    var openHABUsername = ""
    var openHABPassword = ""
    var ignoreSSLCertificate = false
    var cellCount: Int = 0
    var drawerItems: [AnyHashable] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
        drawerItems = [AnyHashable]()
        sitemaps = []
        loadSettings()
        print("OpenHABDrawerTableViewController did load")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("OpenHABDrawerTableViewController viewWillAppear")

        if let sitemapsUrl = Endpoint.sitemaps(openHABRootUrl: openHABRootUrl).url {
            var sitemapsRequest = URLRequest(url: sitemapsUrl)
            sitemapsRequest.setAuthCredentials(openHABUsername, openHABPassword)
            let operation = AFHTTPRequestOperation(request: sitemapsRequest)
            let policy = AFRememberingSecurityPolicy(pinningMode: AFSSLPinningMode.none)
            operation.securityPolicy = policy
            if ignoreSSLCertificate {
                print("Warning - ignoring invalid certificates")
                operation.securityPolicy.allowInvalidCertificates = true
            }

            operation.setCompletionBlockWithSuccess({ operation, responseObject in
                let response = responseObject as? Data
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                self.sitemaps = []
                print("Sitemap response")
                // If we are talking to openHAB 1.X, talk XML
                if self.appData()?.openHABVersion == 1 {
                    print("openHAB 1")
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
                    } else {
                        return
                    }
                } else {
                    // Newer versions speak JSON!
                    let decoder = JSONDecoder()
                    if let response = response {
                        print("openHAB 2")
                        do {
                            os_log("Response will be decoded by JSON", log: .remoteAccess, type: .info)
                            let sitemapsCodingData = try decoder.decode([OpenHABSitemap.CodingData].self, from: response)
                            for sitemapCodingDatum in sitemapsCodingData {
                                if sitemapsCodingData.count != 1 && sitemapCodingDatum.name != "_default" {
                                    print("Sitemap \(sitemapCodingDatum.label)")
                                    self.sitemaps.append(sitemapCodingDatum.openHABSitemap)
                                }
                            }
                        } catch {
                            print("Should not throw \(error)")
                        }
                    }
                }

                // Sort the sitemaps alphabetically.
                self.sitemaps.sort { $0.name < $1.name }

                self.appData()?.sitemaps = self.sitemaps
                self.tableView.reloadData()
            }, failure: { operation, error in
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                print("Error:------>\(error.localizedDescription)")
                print(String(format: "error code %ld", Int(operation.response?.statusCode ?? 0)))
            })
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            operation.start()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        drawerItems.removeAll()
        // check if we are using my.openHAB, add notifications menu item then
        let prefs = UserDefaults.standard

        // Actually this should better test whether the host of the remoteUrl is on openhab.org
        if prefs.string(forKey: "remoteUrl")?.contains("openhab.org") ?? false {
            let notificationsItem = OpenHABDrawerItem()
            notificationsItem.label = "Notifications"
            notificationsItem.tag = "notifications"
            notificationsItem.icon = "glyphicons-334-bell.png"
            drawerItems.append(notificationsItem)
        }
        // Settings always go last
        let settingsItem = OpenHABDrawerItem()
        settingsItem.label = "Settings"
        settingsItem.tag = "settings"
        settingsItem.icon = "glyphicons-137-cogwheel.png"
        drawerItems.append(settingsItem)
        //    self.sitemaps = [[self appData] sitemaps];
        tableView.reloadData()
        print("RightDrawerViewController viewDidAppear")
        print(String(format: "Sitemaps count: %lu", UInt(sitemaps.count)))
        print(String(format: "Menu items count: %lu", UInt(drawerItems.count)))
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated) // Call the super class implementation.
        print("RightDrawerViewController viewDidDisappear")
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
        // Empty first (index 0) row + sitemaps + menu items
        return 1 + sitemaps.count + drawerItems.count
    }

    static let tableViewCellIdentifier = "DrawerCell"

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: DrawerUITableViewCell?
        if indexPath.row != 0 {
            cell = tableView.dequeueReusableCell(withIdentifier: OpenHABDrawerTableViewController.tableViewCellIdentifier) as? DrawerUITableViewCell

            if indexPath.row <= sitemaps.count && sitemaps.count > 0 {
                cell?.customTextLabel?.text = sitemaps[indexPath.row - 1].label
                let iconURL = Endpoint.iconForDrawer(rootUrl: openHABRootUrl, version: appData()?.openHABVersion ?? 2, icon: sitemaps[indexPath.row - 1].icon ).url
                cell?.customImageView?.sd_setImage(with: iconURL, placeholderImage: UIImage(named: "icon-76x76.png"), options: [])
            } else {
                // Then menu items
                cell?.customTextLabel?.text = (drawerItems[indexPath.row - sitemaps.count - 1] as? OpenHABDrawerItem)?.label
                let iconUrlString: String? = nil
                cell?.customImageView?.sd_setImage(with: URL(string: iconUrlString ?? ""), placeholderImage: UIImage(named: (drawerItems[indexPath.row - sitemaps.count - 1] as? OpenHABDrawerItem)?.icon ?? ""), options: [])
            }
            cell?.separatorInset = UIEdgeInsets(top: 0, left: 60, bottom: 0, right: 0)
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: OpenHABDrawerTableViewController.tableViewCellIdentifier) as? DrawerUITableViewCell
            //cell = UITableViewCell(style: .default, reuseIdentifier: OpenHABDrawerTableViewController.tableViewCellIdentifier) as? DrawerUITableViewCell

        }

        cell?.preservesSuperviewLayoutMargins = false
        cell?.layoutMargins = .zero

        return cell!
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 0 {
            return 64
        } else {
            return 44
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // open a alert with an OK and cancel button
        print(String(format: "Clicked on drawer row #%ld", indexPath.row))
        tableView.deselectRow(at: indexPath, animated: false)
        if indexPath.row != 0 {
            // First sitemaps
            if indexPath.row <= sitemaps.count && sitemaps.count > 0 {
                let sitemap = sitemaps[indexPath.row - 1]
                let prefs = UserDefaults.standard
                prefs.setValue(sitemap.name, forKey: "defaultSitemap")
                appData()?.rootViewController?.pageUrl = ""
                let nav = mm_drawerController.centerViewController as? UINavigationController
                let dummyViewController: UIViewController? = storyboard?.instantiateViewController(withIdentifier: "DummyViewController")
                if let dummyViewController = dummyViewController {
                    nav?.pushViewController(dummyViewController, animated: false)
                }
                nav?.popToRootViewController(animated: true)
            } else {
                // Then menu items
                if ((drawerItems[indexPath.row - sitemaps.count - 1] as? OpenHABDrawerItem)?.tag) == "settings" {
                    let nav = mm_drawerController.centerViewController as? UINavigationController
                    let newViewController = storyboard?.instantiateViewController(withIdentifier: "OpenHABSettingsViewController") as? OpenHABSettingsViewController
                    if let newViewController = newViewController {
                        nav?.pushViewController(newViewController, animated: true)
                    }
                }
                if ((drawerItems[indexPath.row - sitemaps.count - 1] as? OpenHABDrawerItem)?.tag) == "notifications" {
                    let nav = mm_drawerController.centerViewController as? UINavigationController
                    if nav?.visibleViewController is OpenHABNotificationsViewController {
                        print("Notifications are already open")
                    } else {
                        let newViewController = storyboard?.instantiateViewController(withIdentifier: "OpenHABNotificationsViewController") as? OpenHABNotificationsViewController
                        if let newViewController = newViewController {
                            nav?.pushViewController(newViewController, animated: true)
                        }
                    }
                }
            }
        }
        mm_drawerController.closeDrawer(animated: true, completion: nil)
    }

    func loadSettings() {
        let prefs = UserDefaults.standard
        openHABUsername = prefs.string(forKey: "username") ?? ""
        openHABPassword = prefs.string(forKey: "password") ?? ""
        ignoreSSLCertificate = prefs.bool(forKey: "ignoreSSL")
    }

    // App wide data access
    func appData() -> OpenHABDataObject? {
        let theDelegate = UIApplication.shared.delegate as? AppDelegate?
        return theDelegate??.appData
    }
}
