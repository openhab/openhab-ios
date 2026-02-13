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

/// Immutable snapshot of widget values required for row rendering.
public struct WidgetDisplayState: Sendable {
    public let widgetId: String
    public let labelText: String
    public let labelValue: String?
    public let effectiveState: String
    public let isOn: Bool
    public let adjustedValue: Double
    public let minValue: Double
    public let maxValue: Double
    public let step: Double
    public let switchSupport: Bool
    public let hasLinkedPage: Bool
    public let readOnly: Bool
    public let mappings: [OpenHABWidgetMapping]
    public let hasPressReleaseMappings: Bool
    public let selectedIndex: Int?
    public let selectedLabel: String?
}

public extension OpenHABWidget {
    var displayState: WidgetDisplayState {
        let mappings = mappingsOrItemOptions
        let effectiveState = state.isEmpty ? (item?.state ?? "") : state
        let selectedIndex = mappingIndex(byCommand: item?.state).map { Int($0) }
        let selectedLabel = selectedIndex.flatMap { index in
            mappings.indices.contains(index) ? mappings[index].label : nil
        }

        return WidgetDisplayState(
            widgetId: widgetId,
            labelText: labelText ?? label,
            labelValue: labelValue,
            effectiveState: effectiveState,
            isOn: effectiveState.parseAsBool(),
            adjustedValue: adjustedValue,
            minValue: minValue,
            maxValue: maxValue,
            step: step,
            switchSupport: switchSupport,
            hasLinkedPage: linkedPage != nil,
            readOnly: readOnly ?? false,
            mappings: mappings,
            hasPressReleaseMappings: hasPressReleaseMappings,
            selectedIndex: selectedIndex,
            selectedLabel: selectedLabel
        )
    }
}
