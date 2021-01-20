// Copyright (c) 2010-2021 Contributors to the openHAB project
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
import OpenHABCore
import os.log
import SideMenu
import UIKit

class OpenHABNotificationsViewController: UITableViewController, SideMenuNavigationControllerDelegate {
    static let tableViewCellIdentifier = "NotificationCell"

    var notifications: NSMutableArray = []
    var openHABRootUrl = ""
    var openHABUsername = ""
    var openHABPassword = ""
    var hamburgerButton: DynamicButton!

    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        notifications = []
        tableView.tableFooterView = UIView()
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(OpenHABNotificationsViewController.handleRefresh(_:)), for: .valueChanged)
        if let refreshControl = refreshControl {
            tableView.refreshControl = refreshControl
        }

        hamburgerButton = DynamicButton(frame: CGRect(x: 0, y: 0, width: 31, height: 31))
        hamburgerButton.setStyle(.hamburger, animated: true)
        hamburgerButton.addTarget(self, action: #selector(OpenHABViewController.rightDrawerButtonPress(_:)), for: .touchUpInside)
        hamburgerButton.strokeColor = view.tintColor

        let hamburgerButtonItem = UIBarButtonItem(customView: hamburgerButton)
        navigationItem.setRightBarButton(hamburgerButtonItem, animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadSettings()
        loadNotifications()
    }

    func loadNotifications() {
        NetworkConnection.notification(urlString: Preferences.remoteUrl) { response in
            switch response.result {
            case .success:
                if let data = response.result.value {
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)
                        let codingDatas = try data.decoded(as: [OpenHABNotification.CodingData].self, using: decoder)
                        for codingDatum in codingDatas {
                            self.notifications.add(codingDatum.openHABNotification)
                        }
                    } catch {
                        os_log("%{PUBLIC}@ ", log: .default, type: .error, error.localizedDescription)
                    }

                    self.refreshControl?.endRefreshing()
                    self.tableView.reloadData()
                }
            case let .failure(error):
                os_log("%{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
                self.refreshControl?.endRefreshing()
            }
        }
    }

    @objc
    func handleRefresh(_ refreshControl: UIRefreshControl?) {
        os_log("Refresh pulled", log: .default, type: .info)
        loadNotifications()
    }

    @objc
    func rightDrawerButtonPress(_ sender: Any?) {
        present(SideMenuManager.default.rightMenuNavigationController!, animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        notifications.count
    }

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

        if let iconUrl = Endpoint.icon(
            rootUrl: appData!.openHABRootUrl,
            version: appData!.openHABVersion,
            icon: notification.icon,
            state: "",
            iconType: .png
        ).url {
            cell?.imageView?.kf.setImage(
                with: iconUrl,
                placeholder: UIImage(named: "openHABIcon")
            )
        }

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
        appData?.openHABUsername = Preferences.username
        appData?.openHABPassword = Preferences.password
    }
}

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
