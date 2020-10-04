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

import OpenHABCore
import os.log
import UIKit

class OpenHABClientCertificatesViewController: UITableViewController {
    static let tableViewCellIdentifier = "ClientCertificatesCell"

    var clientCertificates: [SecIdentity] = []

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = NSLocalizedString("client_certificates", comment: "")
        os_log("OpenHABClientCertificatesViewController viewDidLoad", log: .default, type: .info)

        tableView.tableFooterView = UIView()
        tableView.allowsMultipleSelectionDuringEditing = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        NetworkConnection.shared.clientCertificateManager.clientIdentities.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: OpenHABClientCertificatesViewController.tableViewCellIdentifier, for: indexPath)
        cell.textLabel?.text = NetworkConnection.shared.clientCertificateManager.getIdentityName(index: indexPath.row)
        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCell.EditingStyle.delete {
            let status = NetworkConnection.shared.clientCertificateManager.deleteFromKeychain(index: indexPath.row)
            if status == noErr {
                tableView.deleteRows(at: [indexPath], with: .fade)
            }
        }
    }
}
