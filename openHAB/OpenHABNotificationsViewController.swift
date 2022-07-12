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

import OpenHABCore
import os.log
import SideMenu
import UIKit

class OpenHABNotificationsViewController: UITableViewController {
    static let tableViewCellIdentifier = "NotificationCell"

    var notifications: NSMutableArray = []
    var openHABRootUrl = ""
    var openHABUsername = ""
    var openHABPassword = ""

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

        navigationItem.largeTitleDisplayMode = .never
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadSettings()
        loadNotifications()
    }

    func loadNotifications() {
        NetworkConnection.notification(urlString: Preferences.remoteUrl) { response in
            switch response.result {
            case let .success(data):
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)
                    let codingDatas = try data.decoded(as: [OpenHABNotification.CodingData].self, using: decoder)
                    self.notifications = []
                    for codingDatum in codingDatas {
                        self.notifications.add(codingDatum.openHABNotification)
                    }
                } catch {
                    os_log("%{PUBLIC}@ ", log: .default, type: .error, error.localizedDescription)
                }

                self.refreshControl?.endRefreshing()
                self.tableView.reloadData()

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
