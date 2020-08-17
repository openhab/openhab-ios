// Copyright (c) 2010-2020 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Foundation

import OpenHABCore
import os.log
import UIKit

class HABPanelViewController: UITableViewController {
    static let tableViewCellIdentifier = "WebUITableViewCell"

    var clientCertificates: [SecIdentity] = []

    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("HABPanelViewController viewDidLoad", log: .default, type: .info)

        tableView.tableFooterView = UIView()
        tableView.allowsMultipleSelectionDuringEditing = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        tableView.reloadData()
    }

    /// Return the number of rows in the section.
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: HABPanelViewController.tableViewCellIdentifier, for: indexPath) as WebUITableViewCell
        let cell = tableView.dequeueReusableCell(for: indexPath) as WebUITableViewCell
        // if let cell = cell as? GenericUITableViewCell {
        cell.widget = OpenHABWidget()
        cell.widget.url = Endpoint.habpanel(rootUrl: appData?.openHABRootUrl ?? "").url?.absoluteString ?? ""
        cell.displayWidget()
        // }
        return cell
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        44.0
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        440.0
    }
}
