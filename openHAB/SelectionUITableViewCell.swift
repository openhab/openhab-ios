// Copyright (c) 2010-2020 Contributors to the openHAB project
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

class SelectionUITableViewCell: GenericUITableViewCell {
    override var widget: OpenHABWidget! {
        get {
            super.widget
        }
        set(widget) {
            super.widget = widget
            accessoryType = .disclosureIndicator
            selectionStyle = .blue
        }
    }

    override func displayWidget() {
        super.customTextLabel?.text = widget.labelText
        if let selectedMapping = widget.mappingIndex(byCommand: widget.item?.state) {
            if let widgetMapping = widget?.mappingsOrItemOptions[Int(selectedMapping)] {
                customDetailTextLabel?.text = widgetMapping.label
            }
        } else {
            customDetailTextLabel?.text = ""
        }
    }
}
