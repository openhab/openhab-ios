// Copyright (c) 2010-2019 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import SDWebImage
import UIKit

class OpenHABNotificationsViewController: UITableViewController {
    static let tableViewCellIdentifier = "NotificationCell"

    var notifications: NSMutableArray = []
    var openHABRootUrl = ""
    var openHABUsername = ""
    var openHABPassword = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        notifications = []
        tableView.tableFooterView = UIView()
        refreshControl = UIRefreshControl()
        refreshControl?.backgroundColor = UIColor.groupTableViewBackground
        //    self.refreshControl.tintColor = [UIColor whiteColor];
        refreshControl?.addTarget(self, action: #selector(OpenHABNotificationsViewController.handleRefresh(_:)), for: .valueChanged)
        if let refreshControl = refreshControl {
            tableView.addSubview(refreshControl)
        }
        if let refreshControl = refreshControl {
            tableView.sendSubviewToBack(refreshControl)
        }
        let rightDrawerButton = MMDrawerBarButtonItem(target: self, action: #selector(OpenHABNotificationsViewController.rightDrawerButtonPress(_:)))
        navigationItem.setRightBarButton(rightDrawerButton, animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadSettings()
        loadNotifications()
    }

    func loadNotifications() {
        let prefs = UserDefaults.standard
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        var notificationsUrlString: String?
        if let value = prefs.value(forKey: "remoteUrl") {
            notificationsUrlString = "\(value)/api/v1/notifications?limit=20"
        }
        let notificationsUrl = URL(string: notificationsUrlString ?? "")
        var notificationsRequest: NSMutableURLRequest?
        if let notificationsUrl = notificationsUrl {
            notificationsRequest = NSMutableURLRequest(url: notificationsUrl)
        }
        var operation: OpenHABHTTPRequestOperation?
        if let notificationsRequest = notificationsRequest {
            operation = OpenHABHTTPRequestOperation(request: notificationsRequest as URLRequest)
        }
        operation?.responseSerializer = AFJSONResponseSerializer()
        operation?.setCompletionBlockWithSuccess({ _, responseObject in
            let response = responseObject as? Data
            self.notifications = []
            print("Notifications response")
            // If we are talking to openHAB 1.X, talk XML
            if response is [Any] {
                print("Response is array")
                for notificationJson: Any? in responseObject as! [Any?] {
                    let notification = OpenHABNotification(dictionary: notificationJson as! [AnyHashable: Any] as! [String: Any])
                    self.notifications.add(notification)
                }
            } else {
                print("Response is not array")
                return
            }
            self.refreshControl?.endRefreshing()
            self.tableView.reloadData()
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }, failure: { operation, error in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            print("Error:------>\(error.localizedDescription)")
            print(String(format: "error code %ld", Int(operation.response?.statusCode ?? 0)))
            self.refreshControl?.endRefreshing()
        })
        operation?.start()
    }

    @objc
    func handleRefresh(_ refreshControl: UIRefreshControl?) {
        print("Refresh pulled")
        loadNotifications()
    }

    @objc
    func rightDrawerButtonPress(_ sender: Any?) {
        mm_drawerController.toggle(MMDrawerSide.right, animated: true, completion: nil)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notifications.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: OpenHABNotificationsViewController.tableViewCellIdentifier) as? NotificationTableViewCell
        let notification = notifications[indexPath.row] as? OpenHABNotification
        cell?.textLabel?.text = notification?.message
        // First convert date of notification from UTC from my.OH to local time for device
        let timeZoneSeconds = TimeInterval(NSTimeZone.local.secondsFromGMT())
        let createdInLocalTimezone = notification?.created?.addingTimeInterval(timeZoneSeconds)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.S'Z'"
        cell?.detailTextLabel?.text = dateFormatter.string(from: createdInLocalTimezone!)

        var iconUrlString: String?
        if appData()?.openHABVersion == 2 {
            if let app = appData()?.openHABRootUrl, let icon = notification?.icon {
                iconUrlString = "\(app)/icon/\(icon).png"
            }
        } else {
            if let app = appData()?.openHABRootUrl, let icon = notification?.icon {
                iconUrlString = "\(app)/images/\(icon).png"
            }
        }
        print("\(iconUrlString ?? "")")
        cell?.imageView?.sd_setImage(with: URL(string: iconUrlString ?? ""), placeholderImage: UIImage(named: "icon-29x29.png"), options: [])
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
        openHABUsername = prefs.value(forKey: "username") as? String ?? ""
        openHABPassword = prefs.value(forKey: "password") as? String ?? ""
        //    self.defaultSitemap = [prefs valueForKey:@"defaultSitemap"];
        //    self.idleOff = [prefs boolForKey:@"idleOff"];
        appData()?.openHABUsername = openHABUsername
        appData()?.openHABPassword = openHABPassword
    }

    func appData() -> OpenHABDataObject? {
        let theDelegate = UIApplication.shared.delegate as? OpenHABAppDataDelegate?
        return theDelegate??.appData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
