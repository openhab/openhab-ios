// Copyright (c) 2010-2019 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Foundation
import SwiftUI

class Item: Identifiable {
    private static var idSequence = sequence(first: 1) { $0 + 1 }

    var id: Int

    let name: String
    let label: String
    var state: Bool
    let link: String
    @Published private(set) var image = UIImage(named: "placeholder")

    init?(name: String, label: String, state: Bool, link: String) {
        self.name = name
        self.label = label
        self.state = state
        self.link = link
        guard let id = Item.idSequence.next() else { return nil }
        self.id = id
    }

    func lazyLoadImage(url: URL) {
        URLSession.shared.dataTask(with: url) { (data, _, _) -> Void in
            DispatchQueue.main.async {
                if let data = data, let img = UIImage(data: data) {
                    self.image = img
                }
            }
        }
        .resume()
    }
}

extension Item {
    convenience init? (with codingData: OpenHABItem.CodingData?) {
        guard let codingData = codingData else { return nil }
        self.init(name: codingData.name, label: codingData.label ?? "", state: codingData.state == "true" ? true : false, link: codingData.link)
    }
}
