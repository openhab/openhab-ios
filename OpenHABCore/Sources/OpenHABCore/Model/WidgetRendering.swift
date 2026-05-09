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
import UIKit

/// Shared interface implemented by both OpenHABWidget and WidgetMappingSnapshot.
/// All computed properties in the protocol extension are defined exactly once
/// and derived from the stored-property requirements below.
public protocol WidgetRendering {
    var widgetId: String { get }
    var label: String { get }
    var widgetType: OpenHABWidget.WidgetType { get }
    var inputHint: OpenHABWidget.InputHint { get }
    var item: OpenHABItem? { get }
    var mappings: [OpenHABWidgetMapping] { get }
    var state: String { get }
    var minValue: Double { get }
    var maxValue: Double { get }
    var step: Double { get }
    var height: Double? { get }
    var releaseOnly: Bool? { get }
    var switchSupport: Bool { get }
    var hasLinkedPage: Bool { get }
}

// MARK: - Shared implementations

/// Module-private helper — applies the step-quantisation and clamping used by sliders and setpoints.
private func _widgetAdjustStep(_ raw: Double, minValue: Double, maxValue: Double, step: Double) -> Double {
    var adjusted = floor((raw - minValue) / step) * step
    adjusted += minValue
    return adjusted.clamped(to: minValue ... maxValue)
}

public extension WidgetRendering {
    /// Text portion of the label (everything before the first "[").
    var labelText: String {
        label.components(separatedBy: "[")[0].trimmingCharacters(in: .whitespaces)
    }

    /// Value portion of the label (content of the first "[…]"), if present.
    var labelValue: String? {
        guard let firstMatch = label.firstMatch(of: /\[(.*?)\]/.dotMatchesNewlines()) else { return nil }
        return String(firstMatch.1)
    }

    /// Effective mappings: widget mappings → item command options → item state options.
    var mappingsOrItemOptions: [OpenHABWidgetMapping] {
        if mappings.isEmpty, let commandOptions = item?.commandDescription?.commandOptions {
            return commandOptions.map { OpenHABWidgetMapping(command: $0.command, label: $0.label ?? "") }
        }
        if mappings.isEmpty, let stateOptions = item?.stateDescription?.options {
            return stateOptions.map { OpenHABWidgetMapping(command: $0.value, label: $0.label) }
        }
        return mappings
    }

    var hasPressReleaseMappings: Bool {
        mappingsOrItemOptions.contains { $0.hasPressReleaseBehavior }
    }

    var stateValueAsNumberState: NumberState? {
        if !state.isEmpty {
            return state.parseAsNumber(format: item?.stateDescription?.numberPattern)
        }
        return item?.state?.parseAsNumber(format: item?.stateDescription?.numberPattern)
    }

    var adjustedValue: Double {
        guard let item else { return minValue }
        return _widgetAdjustStep(item.stateAsDouble(), minValue: minValue, maxValue: maxValue, step: step)
    }

    var readOnly: Bool {
        item?.stateDescription?.readOnly ?? false
    }

    var renderingKind: WidgetRenderingKind {
        switch widgetType {
        case .switchWidget:
            if !mappings.isEmpty { return .segmentedSwitch }
            if item?.isOfTypeOrGroupType(.switchItem) ?? false { return .toggleSwitch }
            if item?.isOfTypeOrGroupType(.rollershutter) ?? false { return .rollershutterSwitch }
            if !mappingsOrItemOptions.isEmpty { return .segmentedSwitch }
            return .toggleSwitch
        case .slider: return .slider
        case .input: return [.date, .time, .dateTime].contains(inputHint) ? .dateInput : .textInput
        case .text: return .text
        case .frame: return .frame
        case .setpoint: return .setpoint
        case .selection: return .selection
        case .colorpicker: return .colorPicker
        case .image: return .image
        case .chart: return .chart
        case .video: return .video
        case .webview: return .webview
        case .mapview: return .mapview
        case .colortemperaturepicker: return .colorTemperaturePicker
        case .buttongrid: return .buttonGrid
        case .group, .defaultWidget, .button, .unknown: return .generic
        }
    }

    var displayState: WidgetDisplayState {
        let effectiveMappings = mappingsOrItemOptions
        let effectiveState = state.isEmpty ? (item?.state ?? "") : state
        let selectedIndex = mappingIndex(byCommand: item?.state).map { Int($0) }
        let selectedLabel = selectedIndex.flatMap { idx in
            effectiveMappings.indices.contains(idx) ? effectiveMappings[idx].label : nil
        }
        return WidgetDisplayState(
            widgetId: widgetId,
            labelText: labelText,
            labelValue: labelValue,
            effectiveState: effectiveState,
            isOn: effectiveState.parseAsBool(),
            adjustedValue: adjustedValue,
            minValue: minValue,
            maxValue: maxValue,
            step: step,
            switchSupport: switchSupport,
            hasLinkedPage: hasLinkedPage,
            readOnly: readOnly,
            mappings: effectiveMappings,
            hasPressReleaseMappings: hasPressReleaseMappings,
            selectedIndex: selectedIndex,
            selectedLabel: selectedLabel
        )
    }

    func iconState() -> String? {
        guard let item, let itemState = item.state else { return nil }
        guard !itemState.isNoneIcon else { return nil }
        if item.isOfTypeOrGroupType(.color) {
            if widgetType == .slider || (widgetType == .switchWidget && mappings.isEmpty) {
                guard let brightness = itemState.parseAsBrightness() else { return "OFF" }
                let b = String(brightness)
                return widgetType == .switchWidget ? (b == "0" ? "OFF" : "ON") : b
            }
            if let color = itemState.parseAsUIColor() {
                return "#\(color.hexString ?? "000000")"
            }
        } else if item.isOfTypeOrGroupType(.number) || item.isOfTypeOrGroupType(.numberWithDimension) {
            return itemState.parseAsNumber(format: item.stateDescription?.numberPattern)
                .toString(locale: Locale(identifier: "US"))
        } else if widgetType == .switchWidget, mappings.isEmpty, !item.isOfTypeOrGroupType(.rollershutter) {
            return (itemState == "0" || itemState == "OFF") ? "OFF" : "ON"
        }
        return itemState
    }

    func shouldUseSliderUpdatesDuringMove() -> Bool {
        if let releaseOnly { return !releaseOnly }
        guard let item else { return false }
        if item.isOfTypeOrGroupType(.dimmer) ||
            item.isOfTypeOrGroupType(.number) ||
            item.isOfTypeOrGroupType(.color) { return true }
        if item.isOfTypeOrGroupType(.numberWithDimension) {
            return stateValueAsNumberState?.unit == "%"
        }
        return false
    }

    func mappingIndex(byCommand command: String?) -> Int? {
        mappingsOrItemOptions.firstIndex { $0.command == command }
    }
}
