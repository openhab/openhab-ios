//
//  Frame.swift
//  openhabwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 31.05.18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation

class Frame: NSObject {

    let items: [Item]

    init(items: [Item]) {
        self.items = items
    }
}

extension Frame {
    convenience init? (with codingData: OpenHABSitemap.CodingData?) {
        guard let widgets = codingData?.page.widgets else { return nil }
        self.init(items: widgets.compactMap { Item.init(with: $0.item) })
    }
}
