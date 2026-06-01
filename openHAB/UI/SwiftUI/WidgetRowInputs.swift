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

protocol RowWithIconInput {
    var widgetId: String { get }
    var icon: RowIconInput { get }
}

struct RowIconInput: Equatable {
    let icon: String
    let iconColor: String
    let staticIcon: Bool
    let iconState: String?
    let showIcon: Bool

    static func from(widget: OpenHABWidget) -> RowIconInput {
        RowIconInput(
            icon: widget.icon,
            iconColor: widget.iconColor,
            staticIcon: widget.staticIcon ?? false,
            iconState: widget.iconState(),
            showIcon: shouldShowIcon(for: widget)
        )
    }

    private static func shouldShowIcon(for widget: OpenHABWidget) -> Bool {
        switch widget.type {
        case .frame, .image, .chart, .video, .webview:
            false
        default:
            !widget.icon.isEmpty
        }
    }
}

struct SelectionRowInput: Equatable, RowWithIconInput {
    let displayState: WidgetDisplayState
    let mappings: [OpenHABWidgetMapping]
    let labelColor: String
    let valueColor: String
    let readOnly: Bool
    let widgetId: String
    let icon: RowIconInput
    let itemName: String?

    static func from(widget: OpenHABWidget) -> SelectionRowInput {
        let displayState = widget.displayState
        return SelectionRowInput(
            displayState: displayState,
            mappings: displayState.mappings,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            readOnly: widget.readOnly,
            widgetId: displayState.widgetId,
            icon: RowIconInput.from(widget: widget),
            itemName: widget.item?.name
        )
    }
}

struct SegmentedRowInput: Equatable, RowWithIconInput {
    let displayState: WidgetDisplayState
    let mappings: [OpenHABWidgetMapping]
    let labelColor: String
    let valueColor: String
    let widgetId: String
    let icon: RowIconInput
    let itemName: String?

    static func from(widget: OpenHABWidget) -> SegmentedRowInput {
        let displayState = widget.displayState
        return SegmentedRowInput(
            displayState: displayState,
            mappings: displayState.mappings,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            widgetId: displayState.widgetId,
            icon: RowIconInput.from(widget: widget),
            itemName: widget.item?.name
        )
    }
}

struct SetpointRowInput: Equatable, RowWithIconInput {
    let widgetId: String
    let displayState: WidgetDisplayState
    let labelColor: String
    let valueColor: String
    let readOnly: Bool
    let unit: String?
    let numberPattern: String?
    let serverValue: Double
    let icon: RowIconInput
    let itemName: String?

    static func from(widget: OpenHABWidget) -> SetpointRowInput {
        let displayState = widget.displayState
        let numberPattern = if let pattern = widget.pattern, !pattern.isEmpty {
            pattern
        } else {
            widget.item?.stateDescription?.numberPattern
        }
        let unit = resolvedSetpointUnit(from: widget)
        let serverValue: Double
        if let numberState = widget.stateValueAsNumberState {
            serverValue = numberState.value
        } else {
            let parsed = displayState.effectiveState.parseAsNumber(format: numberPattern).value
            serverValue = parsed.isFinite ? parsed : displayState.minValue
        }

        return SetpointRowInput(
            widgetId: widget.widgetId,
            displayState: displayState,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            readOnly: widget.readOnly,
            unit: unit,
            numberPattern: numberPattern,
            serverValue: serverValue,
            icon: RowIconInput.from(widget: widget),
            itemName: widget.item?.name
        )
    }

    private static func resolvedSetpointUnit(from widget: OpenHABWidget) -> String? {
        if let explicitUnit = widget.unit, !explicitUnit.isEmpty {
            return explicitUnit
        }

        let stateText: String = if !widget.state.isEmpty {
            widget.state
        } else {
            widget.item?.state ?? ""
        }
        guard !stateText.isEmpty else { return nil }

        let components = stateText.split(separator: " ").map(String.init)
        guard components.count > 1 else { return nil }
        return components[1]
    }
}

struct ColorPickerRowInput: Equatable, RowWithIconInput {
    let widgetId: String
    let displayState: WidgetDisplayState
    let labelColor: String
    let valueColor: String
    let readOnly: Bool
    let icon: RowIconInput
    let itemName: String?

    var colorCommandKey: String {
        "color-\(widgetId)"
    }

    static func from(widget: OpenHABWidget) -> ColorPickerRowInput {
        ColorPickerRowInput(
            widgetId: widget.widgetId,
            displayState: widget.displayState,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            readOnly: widget.readOnly,
            icon: RowIconInput.from(widget: widget),
            itemName: widget.item?.name
        )
    }
}

struct ToggleRowInput: Equatable, RowWithIconInput {
    let widgetId: String
    let displayState: WidgetDisplayState
    let labelColor: String
    let valueColor: String
    let readOnly: Bool
    let icon: RowIconInput
    let itemName: String?

    static func from(widget: OpenHABWidget) -> ToggleRowInput {
        ToggleRowInput(
            widgetId: widget.widgetId,
            displayState: widget.displayState,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            readOnly: widget.readOnly,
            icon: RowIconInput.from(widget: widget),
            itemName: widget.item?.name
        )
    }
}

struct RollershutterRowInput: Equatable, RowWithIconInput {
    let widgetId: String
    let displayState: WidgetDisplayState
    let labelColor: String
    let valueColor: String
    let icon: RowIconInput
    let itemName: String?

    static func from(widget: OpenHABWidget) -> RollershutterRowInput {
        RollershutterRowInput(
            widgetId: widget.widgetId,
            displayState: widget.displayState,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            icon: RowIconInput.from(widget: widget),
            itemName: widget.item?.name
        )
    }
}

struct InputRowInput: Equatable, RowWithIconInput {
    let widgetId: String
    let renderingKind: WidgetRenderingKind
    let displayState: WidgetDisplayState
    let labelColor: String
    let valueColor: String
    let readOnly: Bool
    let inputHintRawValue: String
    let icon: RowIconInput
    let itemName: String?
    let numberPattern: String?

    var inputHint: OpenHABWidget.InputHint {
        OpenHABWidget.InputHint(rawValue: inputHintRawValue)
    }

    /// Resolves the effective input hint raw value. When the widget/server provides no explicit hint
    /// (`.unknown`), the item type is used to infer `.number` for Number and Number:Dimension items.
    static func resolvedInputHintRawValue(_ rawValue: String, item: OpenHABItem?) -> String {
        guard OpenHABWidget.InputHint(rawValue: rawValue) == .unknown else { return rawValue }
        if item?.isOfTypeOrGroupType(.number) == true ||
            item?.isOfTypeOrGroupType(.numberWithDimension) == true {
            return OpenHABWidget.InputHint.number.rawValue
        }
        return rawValue
    }

    static func from(widget: OpenHABWidget) -> InputRowInput {
        let numberPattern = if let pattern = widget.pattern, !pattern.isEmpty {
            pattern
        } else {
            widget.item?.stateDescription?.numberPattern
        }
        return InputRowInput(
            widgetId: widget.widgetId,
            renderingKind: widget.renderingKind,
            displayState: widget.displayState,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            readOnly: widget.readOnly,
            inputHintRawValue: resolvedInputHintRawValue(widget.inputHint.rawValue, item: widget.item),
            icon: RowIconInput.from(widget: widget),
            itemName: widget.item?.name,
            numberPattern: numberPattern
        )
    }
}

struct ButtonGridRowInput: Equatable, RowWithIconInput {
    struct ButtonInput: Equatable, Identifiable {
        let id: String
        let label: String
        let icon: RowIconInput
        let command: String
        let releaseCommand: String?
        let row: Int
        let column: Int
        let visibility: Bool
        let readOnly: Bool
        let stateless: Bool
        let effectiveState: String
        let itemName: String?
    }

    let widgetId: String
    let displayState: WidgetDisplayState
    let labelColor: String
    let valueColor: String
    let showLabelAndIcon: Bool
    let icon: RowIconInput
    let parentItemName: String?
    let buttons: [ButtonInput]
    let gridRows: Int
    let gridColumns: Int

    static func from(widget: OpenHABWidget) -> ButtonGridRowInput {
        let childButtons = widget.widgets
        let mappingButtons = widget.mappings.enumerated().map { (index, mapping) in
            mapping.toWidget(widgetId: "\(widget.widgetId)-mappings-\(index)", item: widget.item)
        }
        let allButtons = childButtons + mappingButtons
        let typedButtons = allButtons.map { button in
            ButtonInput(
                id: button.widgetId,
                label: button.label,
                icon: RowIconInput.from(widget: button),
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
            widgetId: widget.widgetId,
            displayState: widget.displayState,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            showLabelAndIcon: !widget.label.isEmpty && widget.labelSource == .sitemapDefinition,
            icon: RowIconInput.from(widget: widget),
            parentItemName: widget.item?.name,
            buttons: typedButtons,
            gridRows: gridRows,
            gridColumns: gridColumns
        )
    }
}

struct GenericRowInput: Equatable, RowWithIconInput {
    let widgetId: String
    let displayState: WidgetDisplayState
    let labelColor: String
    let valueColor: String
    let icon: RowIconInput

    static func from(widget: OpenHABWidget) -> GenericRowInput {
        GenericRowInput(
            widgetId: widget.widgetId,
            displayState: widget.displayState,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            icon: RowIconInput.from(widget: widget)
        )
    }
}

struct LinkedPageRowInput: Equatable, RowWithIconInput {
    let widgetId: String
    let displayState: WidgetDisplayState
    let labelColor: String
    let valueColor: String
    let icon: RowIconInput
    let linkedPageLink: String
    let linkedPageTitle: String
    let isFrame: Bool

    static func from(widget: OpenHABWidget) -> LinkedPageRowInput? {
        guard let linkedPage = widget.linkedPage else { return nil }
        return LinkedPageRowInput(
            widgetId: widget.widgetId,
            displayState: widget.displayState,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            icon: RowIconInput.from(widget: widget),
            linkedPageLink: linkedPage.link,
            linkedPageTitle: linkedPage.title,
            isFrame: widget.type == .frame
        )
    }
}

struct ColorTemperatureRowInput: Equatable, RowWithIconInput {
    let widgetId: String
    let displayState: WidgetDisplayState
    let labelColor: String
    let valueColor: String
    let readOnly: Bool
    let minValue: Double
    let maxValue: Double
    let serverValue: Double?
    let icon: RowIconInput
    let itemName: String?

    var colorTemperatureCommandKey: String {
        "color-temperature-\(widgetId)"
    }

    var clampedMinTemperature: Double {
        max(minValue, 1000)
    }

    var clampedMaxTemperature: Double {
        min(maxValue, 10000)
    }

    static func from(widget: OpenHABWidget) -> ColorTemperatureRowInput {
        let parsedValue = if let state = widget.item?.state, !state.isEmpty {
            state.parseAsNumber().value
        } else if !widget.state.isEmpty {
            widget.state.parseAsNumber().value
        } else {
            Double.nan
        }

        return ColorTemperatureRowInput(
            widgetId: widget.widgetId,
            displayState: widget.displayState,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            readOnly: widget.readOnly,
            minValue: widget.minValue,
            maxValue: widget.maxValue,
            serverValue: parsedValue.isFinite ? parsedValue : nil,
            icon: RowIconInput.from(widget: widget),
            itemName: widget.item?.name
        )
    }
}

struct MediaRowInput: Equatable {
    let widgetId: String
    let renderingKind: WidgetRenderingKind
    let displayState: WidgetDisplayState
    let imageDescriptor: WidgetMediaImageDescriptor
    let labelColor: String
    let valueColor: String
    let readOnly: Bool
    let refresh: Int
    let url: String
    let encoding: String
    let labelSourceRawValue: String
    let preferredRowHeight: Double?
    let coordinateLatitude: Double?
    let coordinateLongitude: Double?

    static func from(widget: OpenHABWidget) -> MediaRowInput {
        let coordinate = widget.coordinate
        let hasValidCoordinate = (-90.0 ... 90.0).contains(coordinate.latitude)
            && (-180.0 ... 180.0).contains(coordinate.longitude)
        let url = effectiveURL(for: widget)

        return MediaRowInput(
            widgetId: widget.widgetId,
            renderingKind: widget.renderingKind,
            displayState: widget.displayState,
            imageDescriptor: widget.mediaImageDescriptor,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            readOnly: widget.readOnly,
            refresh: widget.refresh,
            url: url,
            encoding: widget.encoding,
            labelSourceRawValue: widget.labelSource.rawValue,
            preferredRowHeight: WidgetMappingSnapshot.preferredRowHeight(type: widget.type, label: widget.label, height: widget.height),
            coordinateLatitude: hasValidCoordinate ? coordinate.latitude : nil,
            coordinateLongitude: hasValidCoordinate ? coordinate.longitude : nil
        )
    }

    private static func effectiveURL(for widget: OpenHABWidget) -> String {
        guard widget.renderingKind == .video,
              let itemState = widget.item?.state?.trimmingCharacters(in: .whitespacesAndNewlines),
              isAbsoluteURL(itemState) else {
            return widget.url
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
}

struct FrameRowInput: Equatable {
    let widgetId: String
    let displayState: WidgetDisplayState

    static func from(widget: OpenHABWidget) -> FrameRowInput {
        FrameRowInput(
            widgetId: widget.widgetId,
            displayState: widget.displayState
        )
    }
}

struct TextRowInput: Equatable, RowWithIconInput {
    let widgetId: String
    let displayState: WidgetDisplayState
    let labelColor: String
    let valueColor: String
    let icon: RowIconInput

    static func from(widget: OpenHABWidget) -> TextRowInput {
        TextRowInput(
            widgetId: widget.widgetId,
            displayState: widget.displayState,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            icon: RowIconInput.from(widget: widget)
        )
    }
}

struct SliderRowInput: Equatable, RowWithIconInput {
    let widgetId: String
    let displayState: WidgetDisplayState
    let numberPattern: String?
    let unit: String?
    let readOnly: Bool
    let switchSupport: Bool
    let step: Double
    let labelColor: String
    let valueColor: String
    let shouldSendUpdatesDuringMove: Bool
    let serverValue: Double
    let icon: RowIconInput
    let itemName: String?

    var sliderCommandKey: String {
        "slider-\(widgetId)"
    }

    var sliderRange: ClosedRange<Double> {
        displayState.minValue ... displayState.maxValue
    }

    static func from(widget: OpenHABWidget) -> SliderRowInput {
        let displayState = widget.displayState
        let numberPattern = if let pattern = widget.pattern, !pattern.isEmpty {
            pattern
        } else {
            widget.item?.stateDescription?.numberPattern
        }
        let unit = resolvedSliderUnit(from: widget)
        let serverValue = if widget.item != nil {
            displayState.adjustedValue
        } else {
            parseServerValue(displayState: displayState, numberPattern: numberPattern)
        }

        return SliderRowInput(
            widgetId: widget.widgetId,
            displayState: displayState,
            numberPattern: numberPattern,
            unit: unit,
            readOnly: widget.readOnly,
            switchSupport: widget.switchSupport,
            step: widget.step,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            shouldSendUpdatesDuringMove: widget.shouldUseSliderUpdatesDuringMove(),
            serverValue: adjustedToStep(serverValue, displayState: displayState),
            icon: RowIconInput.from(widget: widget),
            itemName: widget.item?.name
        )
    }

    private static func resolvedSliderUnit(from widget: OpenHABWidget) -> String? {
        if let explicitUnit = widget.unit, !explicitUnit.isEmpty {
            return explicitUnit
        }

        let stateText: String = if !widget.state.isEmpty {
            widget.state
        } else {
            widget.item?.state ?? ""
        }
        guard !stateText.isEmpty else { return nil }

        let components = stateText.split(separator: " ").map(String.init)
        guard components.count > 1 else { return nil }
        return components[1]
    }

    private static func parseServerValue(displayState: WidgetDisplayState, numberPattern: String?) -> Double {
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
