//
//  Item.swift
//  openhabwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 31.05.18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation

struct Item {

    let name: String
    let label: String
    var state: String
    let link: String

    init(name: String, label: String, state: String, link: String) {
        self.name = name
        self.label = label
        self.state = state
        self.link = link
    }
}

extension Item {
    init? (with codingData: OpenHABItem.CodingData?) {
        guard let codingData = codingData else { return nil }
        self.init(name: codingData.name, label: codingData.label ?? "", state: codingData.state, link: codingData.link)
    }
}
