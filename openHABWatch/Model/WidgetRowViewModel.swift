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
import Observation
import OpenHABCore
import UIKit

@MainActor
@Observable
final class WidgetRowViewModel {
    var mappings: [OpenHABWidgetMapping] = []
    var selectedIndex: Int?
    var hasPressReleaseMappings = false
    var labelText = ""
    var labelValue: String?
    var selectedLabel: String?
    var effectiveState = ""
    var isOn = false
    var adjustedValue = 0.0
    var minValue = 0.0
    var maxValue = 100.0
    var step = 1.0
    var switchSupport = false
    var hasLinkedPage = false
    var numberState: NumberState?
    var colorState: UIColor?

    init(widget: OpenHABWidget) {
        update(from: widget)
    }

    func update(from widget: OpenHABWidget) {
        let displayState = widget.displayState
        mappings = displayState.mappings
        hasPressReleaseMappings = displayState.hasPressReleaseMappings
        labelText = displayState.labelText
        labelValue = displayState.labelValue
        selectedIndex = displayState.selectedIndex
        selectedLabel = displayState.selectedLabel
        effectiveState = displayState.effectiveState
        isOn = displayState.isOn
        adjustedValue = displayState.adjustedValue
        minValue = displayState.minValue
        maxValue = displayState.maxValue
        step = displayState.step
        switchSupport = displayState.switchSupport
        hasLinkedPage = displayState.hasLinkedPage
        numberState = widget.stateValueAsNumberState
        colorState = widget.item?.stateAsUIColor()
    }
}
