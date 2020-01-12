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

import os.log
import UIKit

class OpenHABSelectionTableViewController: UITableViewController {
    static let tableViewCellIdentifier = "SelectionCell"

    var mappings: [AnyHashable] = []
    weak var delegate: OpenHABSelectionTableViewControllerDelegate?
    var selectionItem: OpenHABItem?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        os_log("I have %d mappings", log: .viewCycle, type: .info, mappings.count)

        // Uncomment the following line to preserve selection between presentations.
        // self.clearsSelectionOnViewWillAppear = NO;

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        mappings.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: OpenHABSelectionTableViewController.tableViewCellIdentifier, for: indexPath)
        if let mapping = mappings[indexPath.row] as? OpenHABWidgetMapping {
            cell.textLabel?.text = mapping.label
            if selectionItem?.state == mapping.command {
                os_log("This item is selected", log: .viewCycle, type: .info)
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        os_log("Selected mapping %d", log: .viewCycle, type: .info, indexPath.row)

        if delegate != nil {
            delegate?.didSelectWidgetMapping(indexPath.row)
        }
        navigationController?.popViewController(animated: true)
    }
}
