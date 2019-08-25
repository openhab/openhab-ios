//
//  OpenHABClientCertificatesViewController.swift
//  openHAB
//
//  Created by David O'Neill on 03/09/19.
//  Copyright (c) 2019 David O'Neill. All rights reserved.

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
        os_log("OpenHABClientCertificatesViewController viewDidLoad", log: .default, type: .info)

        tableView.tableFooterView = UIView()
        tableView.allowsMultipleSelectionDuringEditing = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return NetworkConnection.shared.clientCertificateManager.clientIdentities.count
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
