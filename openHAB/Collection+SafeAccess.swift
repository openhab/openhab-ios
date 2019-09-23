//
//  Collection+SafeAccess.swift
//  openHAB
//
//  Created by weak on 02.07.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation

public extension Collection {
    // Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
