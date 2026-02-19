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

import OpenHABCore

struct SelectionRowInput {
    let displayState: WidgetDisplayState
    let mappings: [OpenHABWidgetMapping]
    let labelColor: String
    let valueColor: String
    let readOnly: Bool
    let widgetId: String

    static func from(widget: OpenHABWidget) -> SelectionRowInput {
        let displayState = widget.displayState
        return SelectionRowInput(
            displayState: displayState,
            mappings: displayState.mappings,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            readOnly: widget.readOnly ?? false,
            widgetId: displayState.widgetId
        )
    }
}

struct SegmentedRowInput {
    let displayState: WidgetDisplayState
    let mappings: [OpenHABWidgetMapping]
    let labelColor: String
    let valueColor: String
    let widgetId: String

    static func from(widget: OpenHABWidget) -> SegmentedRowInput {
        let displayState = widget.displayState
        return SegmentedRowInput(
            displayState: displayState,
            mappings: displayState.mappings,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            widgetId: displayState.widgetId
        )
    }
}

struct SetpointRowInput {
    let widgetId: String
    let displayState: WidgetDisplayState
    let labelColor: String
    let valueColor: String
    let readOnly: Bool
    let unit: String?
    let numberPattern: String?
    let serverValue: Double

    static func from(widget: OpenHABWidget) -> SetpointRowInput {
        let displayState = widget.displayState
        let numberPattern = if let pattern = widget.pattern, !pattern.isEmpty {
            pattern
        } else {
            widget.item?.stateDescription?.numberPattern
        }
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
            readOnly: widget.readOnly ?? false,
            unit: widget.unit,
            numberPattern: numberPattern,
            serverValue: serverValue
        )
    }
}

struct ColorPickerRowInput {
    let widgetId: String
    let displayState: WidgetDisplayState
    let labelColor: String
    let valueColor: String
    let readOnly: Bool

    var colorCommandKey: String {
        "color-\(widgetId)"
    }

    static func from(widget: OpenHABWidget) -> ColorPickerRowInput {
        ColorPickerRowInput(
            widgetId: widget.widgetId,
            displayState: widget.displayState,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            readOnly: widget.readOnly ?? false
        )
    }
}

struct ToggleRowInput {
    let widgetId: String
    let displayState: WidgetDisplayState
    let labelColor: String
    let valueColor: String
    let readOnly: Bool

    static func from(widget: OpenHABWidget) -> ToggleRowInput {
        ToggleRowInput(
            widgetId: widget.widgetId,
            displayState: widget.displayState,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            readOnly: widget.readOnly ?? false
        )
    }
}

struct RollershutterRowInput {
    let widgetId: String
    let displayState: WidgetDisplayState
    let labelColor: String
    let valueColor: String

    static func from(widget: OpenHABWidget) -> RollershutterRowInput {
        RollershutterRowInput(
            widgetId: widget.widgetId,
            displayState: widget.displayState,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor
        )
    }
}

struct InputRowInput: Sendable {
    let widgetId: String
    let renderingKind: WidgetRenderingKind
    let displayState: WidgetDisplayState
    let labelColor: String
    let valueColor: String
    let readOnly: Bool
    let inputHintRawValue: String

    var inputHint: OpenHABWidget.InputHint {
        OpenHABWidget.InputHint(rawValue: inputHintRawValue)
    }

    static func from(widget: OpenHABWidget) -> InputRowInput {
        InputRowInput(
            widgetId: widget.widgetId,
            renderingKind: widget.renderingKind,
            displayState: widget.displayState,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            readOnly: widget.readOnly ?? false,
            inputHintRawValue: widget.inputHint.rawValue
        )
    }
}

struct ButtonGridRowInput {
    let widgetId: String
    let displayState: WidgetDisplayState
    let labelColor: String
    let valueColor: String
    let showLabelAndIcon: Bool

    static func from(widget: OpenHABWidget) -> ButtonGridRowInput {
        ButtonGridRowInput(
            widgetId: widget.widgetId,
            displayState: widget.displayState,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            showLabelAndIcon: !widget.label.isEmpty && widget.labelSource == .sitemapDefinition
        )
    }
}

struct GenericRowInput {
    let widgetId: String
    let displayState: WidgetDisplayState
    let labelColor: String
    let valueColor: String

    static func from(widget: OpenHABWidget) -> GenericRowInput {
        GenericRowInput(
            widgetId: widget.widgetId,
            displayState: widget.displayState,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor
        )
    }
}

struct LinkedPageRowInput {
    let widgetId: String
    let displayState: WidgetDisplayState
    let labelColor: String
    let valueColor: String
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
            linkedPageLink: linkedPage.link,
            linkedPageTitle: linkedPage.title,
            isFrame: widget.type == .frame
        )
    }
}

struct ColorTemperatureRowInput {
    let widgetId: String
    let displayState: WidgetDisplayState
    let labelColor: String
    let valueColor: String
    let readOnly: Bool
    let minValue: Double
    let maxValue: Double
    let serverValue: Double?

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
            readOnly: widget.readOnly ?? false,
            minValue: widget.minValue,
            maxValue: widget.maxValue,
            serverValue: parsedValue.isFinite ? parsedValue : nil
        )
    }
}

struct MediaRowInput {
    let widgetId: String
    let renderingKind: WidgetRenderingKind
    let displayState: WidgetDisplayState
    let labelColor: String
    let valueColor: String
    let readOnly: Bool
    let refresh: Int
    let url: String
    let encoding: String
    let labelSourceRawValue: String

    static func from(widget: OpenHABWidget) -> MediaRowInput {
        MediaRowInput(
            widgetId: widget.widgetId,
            renderingKind: widget.renderingKind,
            displayState: widget.displayState,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            readOnly: widget.readOnly ?? false,
            refresh: widget.refresh,
            url: widget.url,
            encoding: widget.encoding,
            labelSourceRawValue: widget.labelSource.rawValue
        )
    }
}

struct FrameRowInput {
    let widgetId: String
    let displayState: WidgetDisplayState

    static func from(widget: OpenHABWidget) -> FrameRowInput {
        FrameRowInput(
            widgetId: widget.widgetId,
            displayState: widget.displayState
        )
    }
}

struct TextRowInput {
    let widgetId: String
    let displayState: WidgetDisplayState
    let labelColor: String
    let valueColor: String

    static func from(widget: OpenHABWidget) -> TextRowInput {
        TextRowInput(
            widgetId: widget.widgetId,
            displayState: widget.displayState,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor
        )
    }
}

struct SliderRowInput {
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
        let serverValue = if widget.item != nil {
            displayState.adjustedValue
        } else {
            parseServerValue(displayState: displayState, numberPattern: numberPattern)
        }

        return SliderRowInput(
            widgetId: widget.widgetId,
            displayState: displayState,
            numberPattern: numberPattern,
            unit: widget.unit,
            readOnly: widget.readOnly ?? false,
            switchSupport: widget.switchSupport,
            step: widget.step,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            shouldSendUpdatesDuringMove: widget.shouldUseSliderUpdatesDuringMove(),
            serverValue: adjustedToStep(serverValue, displayState: displayState)
        )
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
