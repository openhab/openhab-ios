// Copyright (c) 2010-2026 Contributors to the openHAB project
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

/// Stable identity for a row snapshot.
/// Occurrence disambiguates repeated widget IDs in one page payload.
struct RowID: Hashable, Sendable {
    let pageKey: String
    let widgetId: String
    let occurrence: Int

    var rawValue: String {
        "\(pageKey)|\(widgetId)|\(occurrence)"
    }
}

/// Draft immutable row union for a list-driven SwiftUI pipeline.
/// Each row case carries a dedicated typed input.
enum SitemapRowInput: Identifiable, Equatable, Sendable {
    case frame(RowID, FrameRowInput)
    case linked(RowID, LinkedPageRowInput)
    case text(RowID, TextRowInput)
    case slider(RowID, SliderRowInput)
    case selection(RowID, SelectionRowInput)
    case segmented(RowID, SegmentedRowInput)
    case setpoint(RowID, SetpointRowInput)
    case rollershutter(RowID, RollershutterRowInput)
    case toggle(RowID, ToggleRowInput)
    case input(RowID, InputRowInput)
    case colorPicker(RowID, ColorPickerRowInput)
    case media(RowID, MediaRowInput)
    case colorTemperature(RowID, ColorTemperatureRowInput)
    case buttonGrid(RowID, ButtonGridRowInput)
    case generic(RowID, GenericRowInput)

    var id: String {
        rowID.rawValue
    }

    var rowID: RowID {
        switch self {
        case let .frame(id, _),
             let .linked(id, _),
             let .text(id, _),
             let .slider(id, _),
             let .selection(id, _),
             let .segmented(id, _),
             let .setpoint(id, _),
             let .rollershutter(id, _),
             let .toggle(id, _),
             let .input(id, _),
             let .colorPicker(id, _),
             let .media(id, _),
             let .colorTemperature(id, _),
             let .buttonGrid(id, _),
             let .generic(id, _):
            id
        }
    }
}

extension SitemapRowInput {
    func applyingWidgetVersions(_ versions: [String: Int]) -> SitemapRowInput {
        let version = versions[rowID.rawValue] ?? 0

        switch self {
        case let .slider(rowID, input):
            return .slider(rowID, input.withWidgetVersion(version))
        case let .selection(rowID, input):
            return .selection(rowID, input.withWidgetVersion(version))
        case let .segmented(rowID, input):
            return .segmented(rowID, input.withWidgetVersion(version))
        case let .media(rowID, input):
            return .media(rowID, input.withWidgetVersion(version))
        case let .text(rowID, input):
            return .text(rowID, input.withWidgetVersion(version))
        case let .linked(rowID, input):
            return .linked(rowID, input.withWidgetVersion(version))
        case let .generic(rowID, input):
            return .generic(rowID, input.withWidgetVersion(version))
        case .frame,
             .setpoint,
             .rollershutter,
             .toggle,
             .input,
             .colorPicker,
             .colorTemperature,
             .buttonGrid:
            return self
        }
    }
}
