//
//  Item.swift
//  openhabwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 31.05.18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation

class Item: NSObject, NSCoding {

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

    // serializer
    required init(coder decoder: NSCoder) {
        self.name = decoder.decodeObject(forKey: "name") as! String
        self.label = decoder.decodeObject(forKey: "label") as! String
        self.link = decoder.decodeObject(forKey: "link") as! String
        guard let stateString = decoder.decodeObject(forKey: "state") as! String? else {
            self.state = "OFF"
            return
        }
        self.state = stateString

    }

    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "name")
        coder.encode(label, forKey: "label")
        coder.encode(state, forKey: "state")
        coder.encode(link, forKey: "link")
    }
}

extension Item {
    convenience init? (with codingData: OpenHABItem.CodingData?) {
        guard let codingData = codingData else { return nil }
        self.init(name: codingData.name, label: codingData.label, state: codingData.state, link: codingData.link)
    }
}
