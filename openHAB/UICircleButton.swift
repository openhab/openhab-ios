// Copyright (c) 2010-2021 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import os.log
import UIKit

var normalBackgroundColor: UIColor?
var normalTextColor: UIColor?

class UICircleButton: UIButton {
    required init?(coder: NSCoder) {
        super.init(coder: coder)

        layer.borderWidth = 2
        layer.borderColor = UIColor(white: 0, alpha: 0.05).cgColor

        layer.cornerRadius = bounds.size.width / 2.0
    }
}
