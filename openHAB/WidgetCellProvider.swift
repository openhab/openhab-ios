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

// enum WidgetCellFactory {
//    static func provider(for widget: OpenHABWidget) -> WidgetCellProvider.Type {
//        switch widget.type {
//        case .switchWidget:
//            if !widget.mappings.isEmpty {
//                return SegmentedCellProvider.self
//            } else if widget.item?.isOfTypeOrGroupType(.switchItem) ?? false {
//                return SwitchCellProvider.self
//            } else if widget.item?.isOfTypeOrGroupType(.rollershutter) ?? false {
//                return RollershutterCellProvider.self
//            } else if !widget.mappingsOrItemOptions.isEmpty {
//                return SegmentedCellProvider.self
//            } else {
//                return SwitchCellProvider.self
//            }
//
//        case .slider:
//            return widget.switchSupport ? SliderWithSwitchProvider.self : SliderProvider.self
//
//        case .input:
//            if [.date, .time, .datetime].contains(widget.inputHint) {
//                return DatePickerInputProvider.self
//            } else {
//                return TextInputProvider.self
//            }
//
//        case .frame: return FrameCellProvider.self
//        case .setpoint: return SetpointCellProvider.self
//        case .selection: return SelectionCellProvider.self
//        case .colorpicker: return ColorPickerCellProvider.self
//        case .image, .chart: return ImageCellProvider.self
//        case .video: return VideoCellProvider.self
//        case .webview: return WebViewCellProvider.self
//        case .mapview: return MapViewCellProvider.self
//        case .group, .text, .defaultWidget, .unknown:
//            return GenericCellProvider.self
//        }
//    }
// }
