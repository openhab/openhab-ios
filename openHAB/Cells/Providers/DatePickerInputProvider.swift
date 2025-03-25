// Copyright (c) 2010-2025 Contributors to the openHAB project
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
import UIKit

struct DatePickerInputProvider: WidgetCellProvider {
    static var reuseIdentifier: String { "DatePickerUITableViewCell" }

    static func dequeue(from tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        tableView.dequeueReusableCell(for: indexPath) as DatePickerUITableViewCell
    }

    static func configure(cell: UITableViewCell, for widget: OpenHABWidget, controller: OpenHABSitemapViewController) {
        guard let cell = cell as? DatePickerUITableViewCell else { return }
        cell.controller = controller
        cell.widget = widget
        cell.displayWidget()
        cell.touchEventDelegate = controller
    }
}
