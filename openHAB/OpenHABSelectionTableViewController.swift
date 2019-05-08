//
//  OpenHABSelectionTableViewController.swift
//  openHAB
//
//  Created by Victor Belov on 16/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import os.log
import UIKit

@objc class OpenHABSelectionTableViewController: UITableViewController {
    @objc var mappings: [AnyHashable] = []
    @objc weak var delegate: OpenHABSelectionTableViewControllerDelegate?
    @objc var selectionItem: OpenHABItem?

    override init(style: UITableView.Style) {
        super.init(style: style)

        // Custom initialization

    }

    override func viewDidLoad() {
        super.viewDidLoad()

        os_log("I have %d mappings", log: .viewCycle, type: .info, mappings.count)

        // Uncomment the following line to preserve selection between presentations.
        // self.clearsSelectionOnViewWillAppear = NO;

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem;
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
        return mappings.count
    }

    static let tableViewCellIdentifier = "SelectionCell"

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: OpenHABSelectionTableViewController.tableViewCellIdentifier, for: indexPath)
        //cell = UITableViewCell(style: .default, reuseIdentifier: OpenHABSelectionTableViewController.tableViewCellIdentifier)
        let mapping = mappings[indexPath.row] as? OpenHABWidgetMapping
        cell.textLabel?.text = mapping?.label
        if selectionItem?.state == mapping?.command {
            os_log("This item is selected", log: .viewCycle, type: .info)
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
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

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
