//
//  OpenHABViewModel.swift
//  openHABWatchSwift Extension
//
//  Created by Tim Müller-Seydlitz on 19.10.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Combine
import Foundation

final class OpenHABViewModel: ObservableObject {
    @Published var items = [Item]()
    var query = "" {
        didSet {
            if oldValue.isEmpty {
                self.items = []
            } else {
                self.search()
            }
        }
    }

}
