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

    private var kindKey: String {
        switch self {
        case .frame: "frame"
        case .linked: "linked"
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
        case let .toggle(_, input):
            [
                input.widgetId,
                input.displayState.effectiveState,
                input.displayState.labelText,
                input.displayState.labelValue ?? "",
                input.labelColor,
                input.valueColor,
                "\(input.readOnly)",
                input.icon.icon,
                input.icon.iconColor,
                "\(input.icon.staticIcon)",
                input.icon.iconState ?? "",
                "\(input.icon.showIcon)",
                input.itemName ?? ""
            ].joined(separator: "|")
        case let .rollershutter(_, input):
            [
                input.widgetId,
                input.displayState.effectiveState,
                input.displayState.labelText,
                input.displayState.labelValue ?? "",
                input.labelColor,
                input.valueColor
            ].joined(separator: "|")
        case let .input(_, input):
            [
                input.widgetId,
                input.displayState.effectiveState,
                input.displayState.labelText,
                input.displayState.labelValue ?? "",
                input.labelColor,
                input.valueColor,
                "\(input.readOnly)",
                Self.kindRawValue(input.renderingKind),
                input.inputHintRawValue
            ].joined(separator: "|")
        case let .buttonGrid(_, input):
            [
                input.widgetId,
                input.displayState.effectiveState,
                input.displayState.labelText,
                input.displayState.labelValue ?? "",
                input.labelColor,
                input.valueColor,
                "\(input.showLabelAndIcon)",
                input.icon.icon,
                input.icon.iconColor,
                "\(input.icon.staticIcon)",
                input.icon.iconState ?? "",
                "\(input.icon.showIcon)",
                input.parentItemName ?? "",
                "\(input.gridRows)",
                "\(input.gridColumns)",
                input.buttons.map {
                    [
                        $0.id,
                        $0.label,
                        $0.icon.icon,
                        $0.icon.iconColor,
                        "\($0.icon.staticIcon)",
                        $0.icon.iconState ?? "",
                        "\($0.icon.showIcon)",
                        $0.command,
                        $0.releaseCommand ?? "",
                        "\($0.row)",
                        "\($0.column)",
                        "\($0.visibility)",
                        "\($0.readOnly)",
                        "\($0.stateless)",
                        $0.effectiveState,
                        $0.itemName ?? ""
                    ].joined(separator: "~")
                }.joined(separator: ",")
            ].joined(separator: "|")
        case let .colorTemperature(_, input):
            [
                input.widgetId,
                input.displayState.effectiveState,
                input.displayState.labelText,
                input.displayState.labelValue ?? "",
                input.labelColor,
                input.valueColor,
                "\(input.readOnly)",
                "\(input.minValue)",
                "\(input.maxValue)",
                "\(input.serverValue ?? -1)"
            ].joined(separator: "|")
        case let .generic(_, input):
            [
                input.widgetId,
                input.displayState.effectiveState,
                input.displayState.labelText,
                input.displayState.labelValue ?? "",
                input.labelColor,
                input.valueColor,
                input.icon.icon,
                input.icon.iconColor,
                "\(input.icon.staticIcon)",
                input.icon.iconState ?? "",
                "\(input.icon.showIcon)"
            ].joined(separator: "|")
        case let .linked(_, input):
            [
                input.widgetId,
                input.displayState.effectiveState,
                input.displayState.labelText,
                input.displayState.labelValue ?? "",
                input.labelColor,
                input.valueColor,
                input.icon.icon,
                input.icon.iconColor,
                "\(input.icon.staticIcon)",
                input.icon.iconState ?? "",
                "\(input.icon.showIcon)",
                input.linkedPageLink,
                input.linkedPageTitle,
                "\(input.isFrame)"
            ].joined(separator: "|")
        case let .media(_, input):
            [
                input.widgetId,
                input.displayState.effectiveState,
                input.displayState.labelText,
                input.displayState.labelValue ?? "",
                input.labelColor,
                input.valueColor,
                "\(input.readOnly)",
                "\(input.refresh)",
                input.url,
                input.encoding,
                input.labelSourceRawValue,
                Self.kindRawValue(input.renderingKind)
            ].joined(separator: "|")
        case let .frame(_, input):
            [
                input.widgetId,
                input.displayState.effectiveState,
                input.displayState.labelText,
                input.displayState.labelValue ?? ""
            ].joined(separator: "|")
        case let .text(_, input):
            [
                input.widgetId,
                input.displayState.effectiveState,
                input.displayState.labelText,
                input.displayState.labelValue ?? "",
                input.labelColor,
                input.valueColor,
                input.icon.icon,
                input.icon.iconColor,
                "\(input.icon.staticIcon)",
                input.icon.iconState ?? "",
                "\(input.icon.showIcon)"
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
