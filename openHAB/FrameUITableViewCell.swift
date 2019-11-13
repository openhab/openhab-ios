// Copyright (c) 2010-2019 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import UIKit

class FrameUITableViewCell: GenericUITableViewCell {
    required init?(coder: NSCoder) {
        super.init(coder: coder)

        selectionStyle = .none
        separatorInset = .zero
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        separatorInset = .zero
    }

    override func displayWidget() {
        textLabel?.textColor = .ohSecondaryLabel
        textLabel?.font = .preferredFont(forTextStyle: .callout)
        textLabel?.text = widget.label.uppercased()
        contentView.sizeToFit()
    }
}
