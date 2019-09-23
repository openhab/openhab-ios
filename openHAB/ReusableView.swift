//
//  ReusableView.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 09.01.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation
import UIKit

protocol ReusableView {
    static var reuseIdentifier: String { get }
}

extension ReusableView {
    static var reuseIdentifier: String {
        return String(describing: self)
    }
}

extension UITableViewCell: ReusableView {}
