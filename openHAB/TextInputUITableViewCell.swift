//
//  TextInputUITableViewCell.swift
//  openHAB
//
//  Created by Tassilo Karge on 05.05.24.
//  Copyright © 2024 openHAB e.V. All rights reserved.
//

import Foundation

class TextInputUITableViewCell: GenericUITableViewCell {
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
}
