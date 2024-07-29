// Copyright (c) 2010-2024 Contributors to the openHAB project
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

class OpenHABSelectionCollectionViewController: UICollectionViewController {
    private let cellReuseIdentifier = "SelectionCell"

    private lazy var dataSource = makeDataSource()

    var mappings: [OpenHABWidgetMapping] = []
    weak var delegate: OpenHABSelectionTableViewControllerDelegate?
    var selectionItem: OpenHABItem?

    override func viewDidLoad() {
        super.viewDidLoad()

        os_log("I have %d mappings", log: .viewCycle, type: .info, mappings.count)

        collectionView.dataSource = dataSource
        update(with: mappings)
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        os_log("Selected mapping %d", log: .viewCycle, type: .info, indexPath.row)

        delegate?.didSelectWidgetMapping(indexPath.row)
        navigationController?.popViewController(animated: true)
    }
}

private extension OpenHABSelectionCollectionViewController {
    typealias Cell = UICollectionViewListCell
    typealias CellRegistration = UICollectionView.CellRegistration<Cell, OpenHABWidgetMapping>

    enum Section: String, CaseIterable {
        case main
    }

    func makeCellRegistration() -> CellRegistration {
        CellRegistration { cell, _, mapping in

            var content = cell.defaultContentConfiguration()
            content.text = mapping.label

            cell.contentConfiguration = content

            if self.selectionItem?.state == mapping.command {
                os_log("This item is selected", log: .viewCycle, type: .info)
                cell.accessories = [.checkmark()]
            } else {
                cell.accessories = []
            }
        }
    }

    func makeDataSource() -> UICollectionViewDiffableDataSource<Section, OpenHABWidgetMapping> {
        UICollectionViewDiffableDataSource(
            collectionView: collectionView,
            cellProvider: makeCellRegistration().cellProvider
        )
    }

    func update(with list: [OpenHABWidgetMapping], animate: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, OpenHABWidgetMapping>()
        snapshot.appendSections(Section.allCases)
        snapshot.appendItems(list, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: animate)
    }
}
