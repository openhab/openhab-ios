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

// swiftformat:disable:next redundantSendable
struct SnapshotRowInputBuildResult: Sendable {
    let inputs: [SitemapRowInput]
    let rowIDs: [RowID]
    let renderKeys: [WidgetRenderKey]
    let reusedInputCount: Int
}

struct WidgetLinkedPageSnapshot {
    let link: String
    let title: String
}

enum SitemapRowInputSnapshotBuilder {
    static func build(pageKey: String, widgets: [WidgetMappingSnapshot]) -> SnapshotRowInputBuildResult {
        var occurrenceByWidgetID: [String: Int] = [:]
        var inputs: [SitemapRowInput] = []
        var rowIDs: [RowID] = []
        var renderKeys: [WidgetRenderKey] = []

        inputs.reserveCapacity(widgets.count)
        rowIDs.reserveCapacity(widgets.count)
        renderKeys.reserveCapacity(widgets.count)

        for widget in widgets {
            let identityWidgetID = widget.rowIdentityWidgetID()
            occurrenceByWidgetID[identityWidgetID, default: 0] += 1
            let occurrence = occurrenceByWidgetID[identityWidgetID]!
            let rowID = RowID(pageKey: pageKey, widgetId: identityWidgetID, occurrence: occurrence)
            rowIDs.append(rowID)
            renderKeys.append(WidgetRenderKey.from(snapshot: widget))
            inputs.append(SitemapRowInputMapper.map(snapshot: widget, rowID: rowID))
        }

        return SnapshotRowInputBuildResult(inputs: inputs, rowIDs: rowIDs, renderKeys: renderKeys, reusedInputCount: 0)
    }

    static func buildIncrementally(pageKey: String,
                                   widgets: [WidgetMappingSnapshot],
                                   previousRenderKeys: [WidgetRenderKey],
                                   previousInputs: [SitemapRowInput],
                                   previousRowIDs: [RowID]) -> SnapshotRowInputBuildResult {
        guard widgets.count == previousRenderKeys.count,
              widgets.count == previousInputs.count,
              widgets.count == previousRowIDs.count else {
            return build(pageKey: pageKey, widgets: widgets)
        }

        var occurrenceByWidgetID: [String: Int] = [:]
        var inputs: [SitemapRowInput] = []
        var rowIDs: [RowID] = []
        var renderKeys: [WidgetRenderKey] = []
        var reusedInputCount = 0

        inputs.reserveCapacity(widgets.count)
        rowIDs.reserveCapacity(widgets.count)
        renderKeys.reserveCapacity(widgets.count)

        for (offset, snapshot) in widgets.enumerated() {
            let identityWidgetID = snapshot.rowIdentityWidgetID()
            occurrenceByWidgetID[identityWidgetID, default: 0] += 1
            let occurrence = occurrenceByWidgetID[identityWidgetID]!
            let rowID = RowID(pageKey: pageKey, widgetId: identityWidgetID, occurrence: occurrence)
            rowIDs.append(rowID)

            let currentRenderKey = WidgetRenderKey.from(snapshot: snapshot)
            renderKeys.append(currentRenderKey)

            if previousRowIDs[offset] == rowID, previousRenderKeys[offset] == currentRenderKey {
                inputs.append(previousInputs[offset])
                reusedInputCount += 1
            } else {
                inputs.append(SitemapRowInputMapper.map(snapshot: snapshot, rowID: rowID))
            }
        }

        return SnapshotRowInputBuildResult(
            inputs: inputs,
            rowIDs: rowIDs,
            renderKeys: renderKeys,
            reusedInputCount: reusedInputCount
        )
    }
}

// swiftformat:disable:next redundantSendable
struct WidgetMappingSnapshot: Sendable {
    let widgetId: String
    let label: String
    let icon: String
    let widgetTypeRawValue: String
    let url: String
    let period: String
    let minValue: Double
    let maxValue: Double
    let step: Double
    let refresh: Int
    let height: Double?
    let iconColor: String
    let labelColor: String
    let valueColor: String
    let service: String
    let state: String
    let legend: Bool?
    let inputHintRawValue: String
    let encoding: String
    let item: OpenHABItem?
    let linkedPage: WidgetLinkedPageSnapshot?
    let mappings: [OpenHABWidgetMapping]
    let widgets: [WidgetMappingSnapshot]
    let visibility: Bool
    let unit: String?
    let pattern: String?
    let staticIcon: Bool?
    let switchSupport: Bool
    let labelSourceRawValue: String
    let releaseOnly: Bool?
    let row: Int?
    let column: Int?
    let releaseCommand: String?
    let command: String?
    let stateless: Bool?
    let forceAsItem: Bool?
    let yAxisDecimalPattern: String?
    let preferredRowHeight: Double?

    init(widget: OpenHABWidget) {
        widgetId = widget.widgetId
        label = widget.label
        icon = widget.icon
        widgetTypeRawValue = widget.type.rawValue
        url = widget.url
        period = widget.period
        minValue = widget.minValue
        maxValue = widget.maxValue
        step = widget.step
        refresh = widget.refresh
        height = widget.height
        iconColor = widget.iconColor
        labelColor = widget.labelcolor
        valueColor = widget.valuecolor
        service = widget.service
        state = widget.state
        legend = widget.legend
        inputHintRawValue = widget.inputHint.rawValue
        encoding = widget.encoding
        item = widget.item
        linkedPage = widget.linkedPage.map {
            WidgetLinkedPageSnapshot(link: $0.link, title: $0.title)
        }
        mappings = widget.mappings
        widgets = widget.widgets.map { WidgetMappingSnapshot(widget: $0) }
        visibility = widget.visibility
        unit = widget.unit
        pattern = widget.pattern
        staticIcon = widget.staticIcon
        switchSupport = widget.switchSupport
        labelSourceRawValue = widget.labelSource.rawValue
        releaseOnly = widget.releaseOnly
        row = widget.row
        column = widget.column
        releaseCommand = widget.releaseCommand
        command = widget.command
        stateless = widget.stateless
        forceAsItem = widget.forceAsItem
        yAxisDecimalPattern = widget.yAxisDecimalPattern
        preferredRowHeight = WidgetMappingSnapshot.preferredRowHeight(type: widget.type, label: widget.label, height: widget.height)
    }

    init(widgetId: String,
         label: String,
         icon: String,
         widgetTypeRawValue: String,
         item: OpenHABItem?,
         row: Int?,
         column: Int?,
         releaseCommand: String?,
         command: String?) {
        self.widgetId = widgetId
        self.label = label
        self.icon = icon
        self.widgetTypeRawValue = widgetTypeRawValue
        url = ""
        period = ""
        minValue = 0
        maxValue = 100
        step = 1
        refresh = 0
        height = nil
        iconColor = ""
        labelColor = ""
        valueColor = ""
        service = ""
        state = ""
        legend = nil
        inputHintRawValue = "unknown"
        encoding = ""
        self.item = item
        linkedPage = nil
        mappings = []
        widgets = []
        visibility = true
        unit = nil
        pattern = nil
        staticIcon = nil
        switchSupport = false
        labelSourceRawValue = OpenHABWidget.LabelSource.unknown.rawValue
        releaseOnly = nil
        self.row = row
        self.column = column
        self.releaseCommand = releaseCommand
        self.command = command
        stateless = true
        forceAsItem = nil
        yAxisDecimalPattern = nil
        preferredRowHeight = nil
    }
}

extension WidgetMappingSnapshot {
    var widgetType: OpenHABWidget.WidgetType {
        OpenHABWidget.WidgetType(rawValue: widgetTypeRawValue) ?? .unknown
    }

    var inputHint: OpenHABWidget.InputHint {
        switch inputHintRawValue.lowercased() {
        case "text":
            .text
        case "number":
            .number
        case "date":
            .date
        case "time":
            .time
        case "datetime", "dateTime":
            .dateTime
        default:
            .unknown
        }
    }

    var labelSource: OpenHABWidget.LabelSource {
        OpenHABWidget.LabelSource(rawValue: labelSourceRawValue) ?? .unknown
    }

    var hasLinkedPage: Bool {
        linkedPage != nil
    }

    var mediaImageDescriptor: WidgetMediaImageDescriptor {
        let itemPayload: WidgetMediaItemPayloadSnapshot = if let item {
            switch item.getImagePayload() {
            case let .embedded(data):
                .embedded(data)
            case let .link(url):
                .link(url?.absoluteString ?? "")
            case .empty:
                .empty
            }
        } else {
            .empty
        }

        return WidgetMediaImageDescriptor(
            mediaKind: widgetType.mediaKind,
            url: url,
            period: period,
            service: service,
            itemTypeRawValue: item?.type?.rawValue,
            itemName: item?.name,
            legend: legend,
            forceAsItem: forceAsItem,
            yAxisDecimalPattern: yAxisDecimalPattern,
            itemPayload: itemPayload
        )
    }

    static func preferredRowHeight(type: OpenHABWidget.WidgetType, label: String, height: Double?) -> Double? {
        switch type {
        case .frame:
            label.isEmpty ? 0 : 35.0
        case .image, .chart, .video:
            nil
        case .webview, .mapview:
            44.0 * (height ?? 8)
        default:
            44.0
        }
    }

    func rowIdentityWidgetID() -> String {
        if renderingKind == .chart, let itemName = item?.name, !itemName.isEmpty {
            return "chart-\(itemName)"
        }
        return widgetId
    }
}

extension WidgetMappingSnapshot: WidgetRendering {}

private extension OpenHABWidget.WidgetType {
    var mediaKind: WidgetMediaKind {
        switch self {
        case .chart:
            .chart
        case .image:
            .image
        default:
            .other
        }
    }
}

private extension OpenHABWidgetMapping {
    func toSnapshot(widgetId: String, item: OpenHABItem?) -> WidgetMappingSnapshot {
        WidgetMappingSnapshot(
            widgetId: widgetId,
            label: label,
            icon: icon ?? "",
            widgetTypeRawValue: OpenHABWidget.WidgetType.button.rawValue,
            item: item,
            row: row,
            column: column,
            releaseCommand: releaseCommand,
            command: command
        )
    }
}

extension SitemapRowInputMapper {
    static func map(snapshot: WidgetMappingSnapshot, rowID: RowID) -> SitemapRowInput {
        if let input = linkedPageRowInput(from: snapshot) {
            return .linked(rowID, input)
        }

        switch snapshot.renderingKind {
        case .slider:
            return .slider(rowID, sliderRowInput(from: snapshot))
        case .selection:
            return .selection(rowID, selectionRowInput(from: snapshot))
        case .segmentedSwitch:
            return .segmented(rowID, segmentedRowInput(from: snapshot))
        case .frame:
            return .frame(rowID, FrameRowInput(widgetId: snapshot.widgetId, displayState: snapshot.displayState))
        case .text:
            return .text(rowID, textRowInput(from: snapshot))
        case .setpoint:
            return .setpoint(rowID, setpointRowInput(from: snapshot))
        case .rollershutterSwitch:
            return .rollershutter(rowID, rollershutterRowInput(from: snapshot))
        case .toggleSwitch:
            return .toggle(rowID, toggleRowInput(from: snapshot))
        case .dateInput, .textInput:
            return .input(rowID, inputRowInput(from: snapshot))
        case .colorPicker:
            return .colorPicker(rowID, colorPickerRowInput(from: snapshot))
        case .image, .chart, .video, .webview, .mapview:
            return .media(rowID, mediaRowInput(from: snapshot))
        case .colorTemperaturePicker:
            return .colorTemperature(rowID, colorTemperatureRowInput(from: snapshot))
        case .buttonGrid:
            return .buttonGrid(rowID, buttonGridRowInput(from: snapshot))
        case .generic:
            return .generic(rowID, genericRowInput(from: snapshot))
        }
    }

    private static func rowIconInput(from snapshot: WidgetMappingSnapshot) -> RowIconInput {
        RowIconInput(
            icon: snapshot.icon,
            iconColor: snapshot.iconColor,
            staticIcon: snapshot.staticIcon ?? false,
            iconState: snapshot.iconState(),
            showIcon: shouldShowIcon(for: snapshot)
        )
    }

    private static func shouldShowIcon(for snapshot: WidgetMappingSnapshot) -> Bool {
        switch snapshot.widgetType {
        case .frame, .image, .chart, .video, .webview:
            false
        default:
            !snapshot.icon.isEmpty
        }
    }

    private static func selectionRowInput(from snapshot: WidgetMappingSnapshot) -> SelectionRowInput {
        let displayState = snapshot.displayState
        return SelectionRowInput(
            displayState: displayState,
            mappings: displayState.mappings,
            labelColor: snapshot.labelColor,
            valueColor: snapshot.valueColor,
            readOnly: snapshot.readOnly,
            widgetId: displayState.widgetId,
            icon: rowIconInput(from: snapshot),
            itemName: snapshot.item?.name
        )
    }

    private static func segmentedRowInput(from snapshot: WidgetMappingSnapshot) -> SegmentedRowInput {
        let displayState = snapshot.displayState
        return SegmentedRowInput(
            displayState: displayState,
            mappings: displayState.mappings,
            labelColor: snapshot.labelColor,
            valueColor: snapshot.valueColor,
            widgetId: displayState.widgetId,
            icon: rowIconInput(from: snapshot),
            itemName: snapshot.item?.name
        )
    }

    private static func setpointRowInput(from snapshot: WidgetMappingSnapshot) -> SetpointRowInput {
        let displayState = snapshot.displayState
        let numberPattern = if let pattern = snapshot.pattern, !pattern.isEmpty {
            pattern
        } else {
            snapshot.item?.stateDescription?.numberPattern
        }
        let unit = resolvedUnit(from: snapshot)
        let serverValue: Double
        if let numberState = snapshot.stateValueAsNumberState {
            serverValue = numberState.value
        } else {
            let parsed = displayState.effectiveState.parseAsNumber(format: numberPattern).value
            serverValue = parsed.isFinite ? parsed : displayState.minValue
        }

        return SetpointRowInput(
            widgetId: snapshot.widgetId,
            displayState: displayState,
            labelColor: snapshot.labelColor,
            valueColor: snapshot.valueColor,
            readOnly: snapshot.readOnly,
            unit: unit,
            numberPattern: numberPattern,
            serverValue: serverValue,
            icon: rowIconInput(from: snapshot),
            itemName: snapshot.item?.name
        )
    }

    private static func colorPickerRowInput(from snapshot: WidgetMappingSnapshot) -> ColorPickerRowInput {
        ColorPickerRowInput(
            widgetId: snapshot.widgetId,
            displayState: snapshot.displayState,
            labelColor: snapshot.labelColor,
            valueColor: snapshot.valueColor,
            readOnly: snapshot.readOnly,
            icon: rowIconInput(from: snapshot),
            itemName: snapshot.item?.name
        )
    }

    private static func toggleRowInput(from snapshot: WidgetMappingSnapshot) -> ToggleRowInput {
        ToggleRowInput(
            widgetId: snapshot.widgetId,
            displayState: snapshot.displayState,
            labelColor: snapshot.labelColor,
            valueColor: snapshot.valueColor,
            readOnly: snapshot.readOnly,
            icon: rowIconInput(from: snapshot),
            itemName: snapshot.item?.name
        )
    }

    private static func rollershutterRowInput(from snapshot: WidgetMappingSnapshot) -> RollershutterRowInput {
        RollershutterRowInput(
            widgetId: snapshot.widgetId,
            displayState: snapshot.displayState,
            labelColor: snapshot.labelColor,
            valueColor: snapshot.valueColor,
            icon: rowIconInput(from: snapshot),
            itemName: snapshot.item?.name
        )
    }

    private static func inputRowInput(from snapshot: WidgetMappingSnapshot) -> InputRowInput {
        let numberPattern = if let pattern = snapshot.pattern, !pattern.isEmpty {
            pattern
        } else {
            snapshot.item?.stateDescription?.numberPattern
        }
        return InputRowInput(
            widgetId: snapshot.widgetId,
            renderingKind: snapshot.renderingKind,
            displayState: snapshot.displayState,
            labelColor: snapshot.labelColor,
            valueColor: snapshot.valueColor,
            readOnly: snapshot.readOnly,
            inputHintRawValue: InputRowInput.resolvedInputHintRawValue(snapshot.inputHintRawValue, item: snapshot.item),
            icon: rowIconInput(from: snapshot),
            itemName: snapshot.item?.name,
            numberPattern: numberPattern
        )
    }

    private static func buttonGridRowInput(from snapshot: WidgetMappingSnapshot) -> ButtonGridRowInput {
        let childButtons = snapshot.widgets
        let mappingButtons = snapshot.mappings.enumerated().map { index, mapping in
            mapping.toSnapshot(widgetId: "\(snapshot.widgetId)-mappings-\(index)", item: snapshot.item)
        }
        let allButtons = childButtons + mappingButtons
        let typedButtons = allButtons.map { button in
            ButtonGridRowInput.ButtonInput(
                id: button.widgetId,
                label: button.label,
                icon: rowIconInput(from: button),
                command: button.command ?? "",
                releaseCommand: button.releaseCommand,
                row: max((button.row ?? 1) - 1, 0),
                column: max((button.column ?? 1) - 1, 0),
                visibility: button.visibility,
                readOnly: button.readOnly,
                stateless: button.stateless ?? false,
                effectiveState: button.displayState.effectiveState,
                itemName: button.item?.name
            )
        }
        let gridRows = typedButtons.map(\.row).max().map { $0 + 1 } ?? 1
        let gridColumns = min((typedButtons.map(\.column).max().map { $0 + 1 } ?? 1), 12)

        return ButtonGridRowInput(
            widgetId: snapshot.widgetId,
            displayState: snapshot.displayState,
            labelColor: snapshot.labelColor,
            valueColor: snapshot.valueColor,
            showLabelAndIcon: !snapshot.label.isEmpty && snapshot.labelSource == .sitemapDefinition,
            icon: rowIconInput(from: snapshot),
            parentItemName: snapshot.item?.name,
            buttons: typedButtons,
            gridRows: gridRows,
            gridColumns: gridColumns
        )
    }

    private static func genericRowInput(from snapshot: WidgetMappingSnapshot) -> GenericRowInput {
        GenericRowInput(
            widgetId: snapshot.widgetId,
            displayState: snapshot.displayState,
            labelColor: snapshot.labelColor,
            valueColor: snapshot.valueColor,
            icon: rowIconInput(from: snapshot)
        )
    }

    private static func linkedPageRowInput(from snapshot: WidgetMappingSnapshot) -> LinkedPageRowInput? {
        guard let linkedPage = snapshot.linkedPage else { return nil }
        return LinkedPageRowInput(
            widgetId: snapshot.widgetId,
            displayState: snapshot.displayState,
            labelColor: snapshot.labelColor,
            valueColor: snapshot.valueColor,
            icon: rowIconInput(from: snapshot),
            linkedPageLink: linkedPage.link,
            linkedPageTitle: linkedPage.title,
            isFrame: snapshot.widgetType == .frame
        )
    }

    private static func colorTemperatureRowInput(from snapshot: WidgetMappingSnapshot) -> ColorTemperatureRowInput {
        let parsedValue = if let state = snapshot.item?.state, !state.isEmpty {
            state.parseAsNumber().value
        } else if !snapshot.state.isEmpty {
            snapshot.state.parseAsNumber().value
        } else {
            Double.nan
        }

        return ColorTemperatureRowInput(
            widgetId: snapshot.widgetId,
            displayState: snapshot.displayState,
            labelColor: snapshot.labelColor,
            valueColor: snapshot.valueColor,
            readOnly: snapshot.readOnly,
            minValue: snapshot.minValue,
            maxValue: snapshot.maxValue,
            serverValue: parsedValue.isFinite ? parsedValue : nil,
            icon: rowIconInput(from: snapshot),
            itemName: snapshot.item?.name
        )
    }

    private static func mediaRowInput(from snapshot: WidgetMappingSnapshot) -> MediaRowInput {
        let coordinate = snapshot.item?.stateAsLocation()?.coordinate
        let hasValidCoordinate = coordinate.map {
            (-90.0 ... 90.0).contains($0.latitude) && (-180.0 ... 180.0).contains($0.longitude)
        } ?? false
        let url = effectiveMediaURL(for: snapshot)

        return MediaRowInput(
            widgetId: snapshot.widgetId,
            renderingKind: snapshot.renderingKind,
            displayState: snapshot.displayState,
            imageDescriptor: snapshot.mediaImageDescriptor,
            labelColor: snapshot.labelColor,
            valueColor: snapshot.valueColor,
            readOnly: snapshot.readOnly,
            refresh: snapshot.refresh,
            url: url,
            encoding: snapshot.encoding,
            labelSourceRawValue: snapshot.labelSourceRawValue,
            preferredRowHeight: snapshot.preferredRowHeight,
            coordinateLatitude: hasValidCoordinate ? coordinate?.latitude : nil,
            coordinateLongitude: hasValidCoordinate ? coordinate?.longitude : nil
        )
    }

    private static func effectiveMediaURL(for snapshot: WidgetMappingSnapshot) -> String {
        guard snapshot.renderingKind == .video,
              let itemState = snapshot.item?.state?.trimmingCharacters(in: .whitespacesAndNewlines),
              isAbsoluteURL(itemState) else {
            return snapshot.url
        }

        return itemState
    }

    private static func isAbsoluteURL(_ value: String) -> Bool {
        guard let url = URL(string: value),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }
        return components.scheme != nil && (components.host != nil || components.path.hasPrefix("/"))
    }

    private static func textRowInput(from snapshot: WidgetMappingSnapshot) -> TextRowInput {
        TextRowInput(
            widgetId: snapshot.widgetId,
            displayState: snapshot.displayState,
            labelColor: snapshot.labelColor,
            valueColor: snapshot.valueColor,
            icon: rowIconInput(from: snapshot)
        )
    }

    private static func sliderRowInput(from snapshot: WidgetMappingSnapshot) -> SliderRowInput {
        let displayState = snapshot.displayState
        let numberPattern = if let pattern = snapshot.pattern, !pattern.isEmpty {
            pattern
        } else {
            snapshot.item?.stateDescription?.numberPattern
        }
        let unit = resolvedUnit(from: snapshot)
        let serverValue = if snapshot.item != nil {
            displayState.adjustedValue
        } else {
            parseSliderServerValue(displayState: displayState, numberPattern: numberPattern)
        }

        return SliderRowInput(
            widgetId: snapshot.widgetId,
            displayState: displayState,
            numberPattern: numberPattern,
            unit: unit,
            readOnly: snapshot.readOnly,
            switchSupport: snapshot.switchSupport,
            step: snapshot.step,
            labelColor: snapshot.labelColor,
            valueColor: snapshot.valueColor,
            shouldSendUpdatesDuringMove: snapshot.shouldUseSliderUpdatesDuringMove(),
            serverValue: adjustedToStep(serverValue, displayState: displayState),
            icon: rowIconInput(from: snapshot),
            itemName: snapshot.item?.name
        )
    }

    private static func resolvedUnit(from snapshot: WidgetMappingSnapshot) -> String? {
        if let explicitUnit = snapshot.unit, !explicitUnit.isEmpty {
            return explicitUnit
        }

        let stateText: String = if !snapshot.state.isEmpty {
            snapshot.state
        } else {
            snapshot.item?.state ?? ""
        }
        guard !stateText.isEmpty else { return nil }

        let components = stateText.split(separator: " ").map { String($0) }
        guard components.count > 1 else { return nil }
        return components[1]
    }

    private static func parseSliderServerValue(displayState: WidgetDisplayState, numberPattern: String?) -> Double {
        let effectiveState = displayState.effectiveState
        if !effectiveState.isEmpty,
           effectiveState != "NULL",
           effectiveState != "UNDEF",
           effectiveState.caseInsensitiveCompare("undefined") != .orderedSame {
            return effectiveState.parseAsNumber(format: numberPattern).value
        }

        if let labelValue = displayState.labelValue, !labelValue.isEmpty {
            return labelValue.parseAsNumber(format: numberPattern).value
        }

        return displayState.adjustedValue
    }

    private static func adjustedToStep(_ raw: Double, displayState: WidgetDisplayState) -> Double {
        let range = displayState.minValue ... displayState.maxValue
        let clamped = raw.clamped(to: range)
        guard displayState.step > 0 else { return clamped }

        var adjusted = floor((clamped - displayState.minValue) / displayState.step) * displayState.step
        adjusted += displayState.minValue
        return adjusted.clamped(to: range)
    }
}
