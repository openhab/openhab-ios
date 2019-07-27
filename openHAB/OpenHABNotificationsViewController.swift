//
//  OpenHABNotificationsViewControllerTableViewController.swift
//  openHAB
//
//  Created by Victor Belov on 24/05/16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import DynamicButton
import os.log
import SDWebImage
import SideMenu
import UIKit

extension UIBarButtonItem {

    static func menuButton(_ target: Any?, action: Selector, imageName: String) -> UIBarButtonItem {
        let button = UIButton(type: .system)
        button.setImage(UIImage(named: imageName), for: .normal)
        button.addTarget(target, action: action, for: .touchUpInside)

        let menuBarItem = UIBarButtonItem(customView: button)
        menuBarItem.customView?.translatesAutoresizingMaskIntoConstraints = false
        menuBarItem.customView?.heightAnchor.constraint(equalToConstant: 24).isActive = true
        menuBarItem.customView?.widthAnchor.constraint(equalToConstant: 24).isActive = true

        return menuBarItem
    }
}

class OpenHABNotificationsViewController: UITableViewController, UISideMenuNavigationControllerDelegate {
    var notifications: NSMutableArray = []
    var openHABRootUrl = ""
    var openHABUsername = ""
    var openHABPassword = ""

    var hamburgerButton: DynamicButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        notifications = []
        tableView.tableFooterView = UIView()
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(OpenHABNotificationsViewController.handleRefresh(_:)), for: .valueChanged)
        if let refreshControl = refreshControl {
            tableView.refreshControl = refreshControl
        }

        self.hamburgerButton = DynamicButton(frame: CGRect(x: 0, y: 0, width: 31, height: 31))
        hamburgerButton.setStyle(.hamburger, animated: true)
        hamburgerButton.addTarget(self, action: #selector(OpenHABViewController.rightDrawerButtonPress(_:)), for: .touchUpInside)
        hamburgerButton.strokeColor = self.view.tintColor

        let hamburgerButtonItem = UIBarButtonItem(customView: hamburgerButton)
        navigationItem.setRightBarButton(hamburgerButtonItem, animated: true)
    }

    func sideMenuWillDisappear(menu: UISideMenuNavigationController, animated: Bool) {
        self.hamburgerButton.setStyle(.hamburger, animated: animated)
    }

    func sideMenuWillAppear(menu: UISideMenuNavigationController, animated: Bool) {
        self.hamburgerButton.setStyle(.arrowRight, animated: animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadSettings()
        loadNotifications()
    }

    func loadNotifications() {
        let prefs = UserDefaults.standard
        UIApplication.shared.isNetworkActivityIndicatorVisible = true

        if let notificationsUrl = Endpoint.notification(prefsURL: prefs.string(forKey: "remoteUrl") ?? "").url {
            var notificationsRequest = URLRequest(url: notificationsUrl)
            notificationsRequest.setAuthCredentials(openHABUsername, openHABPassword)
            let operation = OpenHABHTTPRequestOperation(request: notificationsRequest, delegate: nil)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)

            operation.setCompletionBlockWithSuccess({ operation, responseObject in
                if let response = responseObject as? Data {
                    do {
                        let codingDatas = try decoder.decode([OpenHABNotification.CodingData].self, from: response)
                        for codingDatum in codingDatas {
                            self.notifications.add(codingDatum.openHABNotification)
                        }
                    } catch {
                        os_log("%{PUBLIC}@ ", log: .default, type: .error, error.localizedDescription)
                    }
                }

                self.refreshControl?.endRefreshing()
                self.tableView.reloadData()
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }, failure: { operation, error in
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                os_log("%{PUBLIC}@ %d", log: .default, type: .error, error.localizedDescription, Int(operation.response?.statusCode ?? 0))
                os_log("%{PUBLIC}@ ", log: .default, type: .error, error.localizedDescription)
                self.refreshControl?.endRefreshing()
            })
            operation.start()
        }
    }

    @objc func handleRefresh(_ refreshControl: UIRefreshControl?) {
        os_log("Refresh pulled", log: .default, type: .info)
        loadNotifications()
    }

    @objc func rightDrawerButtonPress(_ sender: Any?) {
        present(SideMenuManager.default.menuRightNavigationController!, animated: true, completion: nil)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notifications.count
    }

    static let tableViewCellIdentifier = "NotificationCell"

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: OpenHABNotificationsViewController.tableViewCellIdentifier) as? NotificationTableViewCell
        guard let notification = notifications[indexPath.row] as? OpenHABNotification else { return UITableViewCell() }

        cell?.customTextLabel?.text = notification.message

        if let timeStamp = notification.created {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .medium
            dateFormatter.timeZone = TimeZone.current
            cell?.customDetailTextLabel?.text = dateFormatter.string(from: timeStamp)
        }

        let iconUrl = Endpoint.icon(rootUrl: appData!.openHABRootUrl, version: appData!.openHABVersion, icon: notification.icon, value: "", iconType: .png).url
        cell?.imageView?.sd_setImage(with: iconUrl, placeholderImage: UIImage(named: "icon-29x29.png"), options: [])
        if cell?.responds(to: #selector(setter: NotificationTableViewCell.preservesSuperviewLayoutMargins)) ?? false {
            cell?.preservesSuperviewLayoutMargins = false
        }
        // Explictly set your cell's layout margins
        if cell?.responds(to: #selector(setter: NotificationTableViewCell.layoutMargins)) ?? false {
            cell?.layoutMargins = .zero
        }
        cell?.separatorInset = UIEdgeInsets(top: 0, left: 60, bottom: 0, right: 0)
        return cell!
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // open a alert with an OK and cancel button
        tableView.deselectRow(at: indexPath, animated: false)
    }

    func loadSettings() {
        let prefs = UserDefaults.standard
        openHABUsername = prefs.string(forKey: "username") ?? ""
        openHABPassword = prefs.string(forKey: "password") ?? ""
        //    self.defaultSitemap = [prefs valueForKey:@"defaultSitemap"];
        //    self.idleOff = [prefs boolForKey:@"idleOff"];
        appData?.openHABUsername = openHABUsername
        appData?.openHABPassword = openHABPassword
    }

    var appData: OpenHABDataObject? {
        return AppDelegate.appDelegate.appData
    }
}
