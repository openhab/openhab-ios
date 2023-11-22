// Copyright (c) 2010-2023 Contributors to the openHAB project
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

// swiftlint:disable:next type_name
public protocol OpenHABSelectionTableViewControllerDelegate: NSObjectProtocol {
    func didSelectWidgetMapping(_ selectedMapping: Int)
}

class OpenHABSelectionTableViewController: UITableViewController {
    private let cellReuseIdentifier = "SelectionCell"

    private lazy var dataSource = makeDataSource()
    private lazy var collectionView = makeCollectionView()

    var mappings: [OpenHABWidgetMapping] = []
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
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
        let mapping = mappings[indexPath.row]
        cell.textLabel?.text = mapping.label
        if selectionItem?.state == mapping.command {
            os_log("This item is selected", log: .viewCycle, type: .info)
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        os_log("Selected mapping %d", log: .viewCycle, type: .info, indexPath.row)

        delegate?.didSelectWidgetMapping(indexPath.row)
        navigationController?.popViewController(animated: true)
    }
}

private extension OpenHABSelectionTableViewController {
    enum Section: String, CaseIterable {
        case uniq
    }
}

private extension OpenHABSelectionTableViewController {
    typealias Cell = UICollectionViewListCell
    typealias CellRegistration = UICollectionView.CellRegistration<Cell, OpenHABWidgetMapping>

    func makeCellRegistration() -> CellRegistration {
        CellRegistration { cell, indexPath, mapping in

            var content = cell.defaultContentConfiguration()
            content.text = mapping.label

            if self.selectionItem?.state == mapping.command {
                os_log("This item is selected", log: .viewCycle, type: .info)
                content.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
            cell.contentConfiguration = content
        }
    }
}

private extension OpenHABSelectionTableViewController {
    func makeDataSource() -> UICollectionViewDiffableDataSource<Section, OpenHABWidgetMapping> {
        UICollectionViewDiffableDataSource(
            collectionView: collectionView,
            cellProvider: makeCellRegistration().cellProvider
        )
    }
}

extension UICollectionView.CellRegistration {
    var cellProvider: (UICollectionView, IndexPath, Item) -> Cell {
        return { collectionView, indexPath, product in
            collectionView.dequeueConfiguredReusableCell(
                using: self,
                for: indexPath,
                item: product
            )
        }
    }
}

extension OpenHABSelectionTableViewController {
    func update(with list: [OpenHABWidgetMapping], animate: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, OpenHABWidgetMapping>()
        snapshot.appendSections(Section.allCases)
        snapshot.appendItems(list, toSection: .uniq)
        dataSource.apply(snapshot, animatingDifferences: animate)
    }
}
