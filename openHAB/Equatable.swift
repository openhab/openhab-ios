//
//  Equatable.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 30.08.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation

extension Equatable {
    func isAny(of candidates: Self...) -> Bool {
        return candidates.contains(self)
    }
}
