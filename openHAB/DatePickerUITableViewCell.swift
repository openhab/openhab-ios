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

import OpenHABCore
import UIKit

class DatePickerUITableViewCell: GenericUITableViewCell {
    static let dateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter
    }()

    override var widget: OpenHABWidget! {
        get {
            super.widget
        }
        set(widget) {
            super.widget = widget
            switch widget.inputHint {
            case .date:
                datePicker.datePickerMode = .date
            case .time:
                datePicker.datePickerMode = .time
            case .datetime:
                datePicker.datePickerMode = .dateAndTime
            default:
                fatalError("Must not use this cell for input other than date and time")
            }
            guard let date = widget.item?.state else {
                datePicker.date = Date()
                return
            }
            datePicker.date = DateFormatter.iso8601Full.date(from: date) ?? Date.now
        }
    }

    weak var controller: OpenHABSitemapViewController!

    @IBOutlet private(set) var datePicker: UIDatePicker! {
        didSet {
            datePicker.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                controller?.sendCommand(widget.item, commandToSend: DateFormatter.iso8601Full.string(from: datePicker.date))
            }, for: .valueChanged)
        }
    }
}
