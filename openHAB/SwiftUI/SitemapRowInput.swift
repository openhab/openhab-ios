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

/// Lightweight generic row input for non-migrated row kinds.
struct BasicWidgetRowInput: Sendable {
    let widgetId: String
    let renderingKind: WidgetRenderingKind
    let displayState: WidgetDisplayState
    let icon: String
    let labelColor: String
    let valueColor: String
    let readOnly: Bool
    let refresh: Int

    static func from(widget: OpenHABWidget) -> BasicWidgetRowInput {
        BasicWidgetRowInput(
            widgetId: widget.widgetId,
            renderingKind: widget.renderingKind,
            displayState: widget.displayState,
            icon: widget.icon,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            readOnly: widget.readOnly ?? false,
            refresh: widget.refresh
        )
    }
}

/// Draft immutable row union for a list-driven SwiftUI pipeline.
/// Hot rows already have dedicated typed inputs.
enum SitemapRowInput: Identifiable, Equatable, Sendable {
    case frame(RowID, BasicWidgetRowInput)
    case text(RowID, BasicWidgetRowInput)
    case slider(RowID, SliderRowInput)
    case selection(RowID, SelectionRowInput)
    case segmented(RowID, SegmentedRowInput)
    case setpoint(RowID, SetpointRowInput)
    case rollershutter(RowID, BasicWidgetRowInput)
    case toggle(RowID, BasicWidgetRowInput)
    case input(RowID, BasicWidgetRowInput)
    case colorPicker(RowID, ColorPickerRowInput)
    case media(RowID, BasicWidgetRowInput)
    case colorTemperature(RowID, BasicWidgetRowInput)
    case buttonGrid(RowID, BasicWidgetRowInput)
    case generic(RowID, BasicWidgetRowInput)

    var id: String {
        rowID.rawValue
    }

    var rowID: RowID {
        switch self {
        case let .frame(id, _),
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

    private var kindKey: String {
        switch self {
        case .frame: "frame"
        case .text: "text"
        case .slider: "slider"
        case .selection: "selection"
        case .segmented: "segmented"
        case .setpoint: "setpoint"
        case .rollershutter: "rollershutter"
        case .toggle: "toggle"
        case .input: "input"
        case .colorPicker: "colorPicker"
        case .media: "media"
        case .colorTemperature: "colorTemperature"
        case .buttonGrid: "buttonGrid"
        case .generic: "generic"
        }
    }

    private var renderSignature: String {
        switch self {
        case let .slider(_, input):
            [
                input.widgetId,
                input.displayState.effectiveState,
                input.displayState.labelText,
                input.displayState.labelValue ?? "",
                input.labelColor,
                input.valueColor,
                "\(input.displayState.minValue)",
                "\(input.displayState.maxValue)",
                "\(input.displayState.step)",
                input.numberPattern ?? "",
                input.unit ?? "",
                "\(input.switchSupport)",
                "\(input.readOnly)"
            ].joined(separator: "|")
        case let .selection(_, input):
            [
                input.widgetId,
                input.displayState.effectiveState,
                input.displayState.labelText,
                input.displayState.labelValue ?? "",
                input.labelColor,
                input.valueColor,
                input.mappings.map { "\($0.command)=\($0.label)" }.joined(separator: ","),
                "\(input.readOnly)"
            ].joined(separator: "|")
        case let .segmented(_, input):
            [
                input.widgetId,
                input.displayState.effectiveState,
                input.displayState.labelText,
                input.displayState.labelValue ?? "",
                input.labelColor,
                input.valueColor,
                input.mappings.map { "\($0.command)=\($0.label)|\($0.releaseCommand ?? "")" }.joined(separator: ",")
            ].joined(separator: "|")
        case let .setpoint(_, input):
            [
                input.widgetId,
                input.displayState.effectiveState,
                input.displayState.labelText,
                input.displayState.labelValue ?? "",
                input.labelColor,
                input.valueColor,
                "\(input.displayState.minValue)",
                "\(input.displayState.maxValue)",
                "\(input.displayState.step)",
                input.unit ?? "",
                input.numberPattern ?? "",
                "\(input.readOnly)"
            ].joined(separator: "|")
        case let .colorPicker(_, input):
            [
                input.widgetId,
                input.displayState.effectiveState,
                input.displayState.labelText,
                input.displayState.labelValue ?? "",
                input.labelColor,
                input.valueColor,
                "\(input.readOnly)"
            ].joined(separator: "|")
        case let .frame(_, input),
             let .text(_, input),
             let .rollershutter(_, input),
             let .toggle(_, input),
             let .input(_, input),
             let .media(_, input),
             let .colorTemperature(_, input),
             let .buttonGrid(_, input),
             let .generic(_, input):
            [
                input.widgetId,
                input.displayState.effectiveState,
                input.displayState.labelText,
                input.displayState.labelValue ?? "",
                input.icon,
                input.labelColor,
                input.valueColor,
                "\(input.readOnly)",
                "\(input.refresh)",
                Self.kindRawValue(input.renderingKind)
            ].joined(separator: "|")
        }
    }

    static func == (lhs: SitemapRowInput, rhs: SitemapRowInput) -> Bool {
        lhs.rowID == rhs.rowID
            && lhs.kindKey == rhs.kindKey
            && lhs.renderSignature == rhs.renderSignature
    }

    private static func kindRawValue(_ kind: WidgetRenderingKind) -> String {
        switch kind {
        case .segmentedSwitch: "segmentedSwitch"
        case .toggleSwitch: "toggleSwitch"
        case .rollershutterSwitch: "rollershutterSwitch"
        case .slider: "slider"
        case .dateInput: "dateInput"
        case .textInput: "textInput"
        case .text: "text"
        case .frame: "frame"
        case .setpoint: "setpoint"
        case .selection: "selection"
        case .colorPicker: "colorPicker"
        case .image: "image"
        case .chart: "chart"
        case .video: "video"
        case .webview: "webview"
        case .mapview: "mapview"
        case .colorTemperaturePicker: "colorTemperaturePicker"
        case .buttonGrid: "buttonGrid"
        case .generic: "generic"
        }
    }
}
