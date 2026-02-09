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
    var adjustedValue: Double = 0.0
    var minValue: Double = 0.0
    var maxValue: Double = 100.0
    var step: Double = 1.0
    var switchSupport = false
    var hasLinkedPage = false
    var numberState: NumberState?
    var colorState: UIColor?

    init(widget: OpenHABWidget) {
        update(from: widget)
    }

    func update(from widget: OpenHABWidget) {
        let newMappings = widget.mappingsOrItemOptions
        mappings = newMappings
        hasPressReleaseMappings = widget.hasPressReleaseMappings
        labelText = widget.labelText ?? widget.label
        labelValue = widget.labelValue
        selectedIndex = widget.mappingIndex(byCommand: widget.item?.state).map { Int($0) }
        if let index = selectedIndex, index >= 0, index < newMappings.count {
            selectedLabel = newMappings[index].label
        } else {
            selectedLabel = nil
        }
        if widget.state.isEmpty {
            effectiveState = widget.item?.state ?? ""
        } else {
            effectiveState = widget.state
        }
        isOn = effectiveState.parseAsBool()
        adjustedValue = widget.adjustedValue
        minValue = widget.minValue
        maxValue = widget.maxValue
        step = widget.step
        switchSupport = widget.switchSupport
        hasLinkedPage = widget.linkedPage != nil
        numberState = widget.stateValueAsNumberState
        colorState = widget.item?.stateAsUIColor()
    }
}
