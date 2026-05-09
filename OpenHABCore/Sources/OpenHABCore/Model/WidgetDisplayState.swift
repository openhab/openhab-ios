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
public struct WidgetDisplayState: Sendable, Equatable {
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

    public init(widgetId: String,
                labelText: String,
                labelValue: String?,
                effectiveState: String,
                isOn: Bool,
                adjustedValue: Double,
                minValue: Double,
                maxValue: Double,
                step: Double,
                switchSupport: Bool,
                hasLinkedPage: Bool,
                readOnly: Bool,
                mappings: [OpenHABWidgetMapping],
                hasPressReleaseMappings: Bool,
                selectedIndex: Int?,
                selectedLabel: String?) {
        self.widgetId = widgetId
        self.labelText = labelText
        self.labelValue = labelValue
        self.effectiveState = effectiveState
        self.isOn = isOn
        self.adjustedValue = adjustedValue
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
        self.switchSupport = switchSupport
        self.hasLinkedPage = hasLinkedPage
        self.readOnly = readOnly
        self.mappings = mappings
        self.hasPressReleaseMappings = hasPressReleaseMappings
        self.selectedIndex = selectedIndex
        self.selectedLabel = selectedLabel
    }
}
