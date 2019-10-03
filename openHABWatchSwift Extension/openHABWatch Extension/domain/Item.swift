//
//  Item.swift
//  openhabwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 31.05.18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation

struct Item: Identifiable {
    private static var idSequence = sequence(first: 1, next: { $0 + 1 })

    var id: Int

    let name: String
    let label: String
    var state: String
    let link: String

    init?(name: String, label: String, state: String, link: String) {
        self.name = name
        self.label = label
        self.state = state
        self.link = link
        guard let id = Item.idSequence.next() else { return nil }
        self.id = id
    }
}

extension Item {
    init? (with codingData: OpenHABItem.CodingData?) {
        guard let codingData = codingData else { return nil }
        self.init(name: codingData.name, label: codingData.label ?? "", state: codingData.state, link: codingData.link)
    }
}
