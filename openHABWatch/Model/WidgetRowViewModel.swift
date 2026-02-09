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

@MainActor
@Observable
final class WidgetRowViewModel {
    var mappings: [OpenHABWidgetMapping] = []
    var selectedIndex: Int?
    var hasPressReleaseMappings = false
    var labelText = ""
    var selectedLabel: String?

    init(widget: OpenHABWidget) {
        update(from: widget)
    }

    func update(from widget: OpenHABWidget) {
        let newMappings = widget.mappingsOrItemOptions
        mappings = newMappings
        hasPressReleaseMappings = widget.hasPressReleaseMappings
        labelText = widget.labelText ?? widget.label
        selectedIndex = widget.mappingIndex(byCommand: widget.item?.state).map { Int($0) }
        if let index = selectedIndex, index >= 0, index < newMappings.count {
            selectedLabel = newMappings[index].label
        } else {
            selectedLabel = nil
        }
    }
}
