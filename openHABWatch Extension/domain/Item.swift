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

class Item: NSObject {
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
    convenience init? (with codingData: OpenHABItem.CodingData?) {
        guard let codingData = codingData else { return nil }
        self.init(name: codingData.name, label: codingData.label ?? "", state: codingData.state, link: codingData.link)
    }
}
