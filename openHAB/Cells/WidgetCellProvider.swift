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

protocol WidgetCellProvider {
    static var reuseIdentifier: String { get }
    static func dequeue(from tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell
    static func configure(cell: UITableViewCell, for widget: OpenHABWidget, controller: OpenHABSitemapViewController)
}

enum WidgetCellFactory {
    static func provider(for widget: OpenHABWidget) -> WidgetCellProvider.Type {
        switch widget.type {
        case .switchWidget:
            if !widget.mappings.isEmpty {
                SegmentedCellProvider.self // 🔥 Done
            } else if widget.item?.isOfTypeOrGroupType(.switchItem) ?? false {
                SwitchCellProvider.self // 🔥 Done
            } else if widget.item?.isOfTypeOrGroupType(.rollershutter) ?? false {
                RollershutterCellProvider.self // 🔥 Done
            } else if !widget.mappingsOrItemOptions.isEmpty {
                SegmentedCellProvider.self
            } else {
                SwitchCellProvider.self
            }
        case .slider:
            widget.switchSupport ? SliderWithSwitchProvider.self : SliderProvider.self // 🔥 Done
        case .input:
            if [.date, .time, .datetime].contains(widget.inputHint) {
                DatePickerInputProvider.self // 🔥 Done
            } else {
                TextInputProvider.self // 🔥 Done
            }
        case .frame: FrameCellProvider.self // 🔥 Done
        case .setpoint: SetpointCellProvider.self // 🔥 Done
        case .selection: SelectionCellProvider.self // 🔥 Done
        case .colorpicker: ColorPickerCellProvider.self // 🔥 Done
        case .image, .chart: ImageCellProvider.self // 🔥 Done
        case .video: VideoCellProvider.self // 🔥 Done
        case .webview: WebViewCellProvider.self // 🔥 Done
        case .mapview: MapViewCellProvider.self // 🔥 Done
        case .group, .text, .defaultWidget, .unknown:
            GenericCellProvider.self // 🔥 Done
        }
    }
}
