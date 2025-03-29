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

enum WidgetCellFactory {
    static func provider(for widget: OpenHABWidget) -> WidgetCellProvider {
        switch widget.type {
        case .switchWidget:
            if !widget.mappings.isEmpty {
                SegmentedCellProvider()
            } else if widget.item?.isOfTypeOrGroupType(.switchItem) ?? false {
                SwitchCellProvider()
            } else if widget.item?.isOfTypeOrGroupType(.rollershutter) ?? false {
                RollershutterCellProvider()
            } else if !widget.mappingsOrItemOptions.isEmpty {
                SegmentedCellProvider()
            } else {
                SwitchCellProvider()
            }
        case .slider:
            if widget.switchSupport {
                SliderWithSwitchProvider()
            } else {
                SliderProvider()
            }
        case .input:
            if [.date, .time, .datetime].contains(widget.inputHint) {
                DatePickerInputProvider()
            } else {
                TextInputProvider()
            }
        case .frame: FrameCellProvider()
        case .setpoint: SetpointCellProvider()
        case .selection: SelectionCellProvider()
        case .colorpicker: ColorPickerCellProvider()
        case .image, .chart: ImageCellProvider()
        case .video: VideoCellProvider()
        case .webview: WebViewCellProvider()
        case .mapview: MapViewCellProvider()
        case .group, .text, .defaultWidget, .unknown:
            GenericCellProvider()
        }
    }
}

protocol WidgetCellProvider {
    var reuseIdentifier: String { get }
    @MainActor func dequeue(from tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell
    @MainActor func configure(cell: UITableViewCell, for widget: OpenHABWidget, controller: OpenHABSitemapViewController)
}
