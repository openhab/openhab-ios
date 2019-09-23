//
//  UICircleButton.swift
//  openHAB
//
//  Created by Victor Belov on 03/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

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
