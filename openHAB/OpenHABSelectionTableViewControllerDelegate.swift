//
//  OpenHABSelectionTableViewControllerDelegate.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 04.01.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation
@objc public protocol OpenHABSelectionTableViewControllerDelegate: NSObjectProtocol {
    func didSelectWidgetMapping(_ selectedMapping: Int)
}
