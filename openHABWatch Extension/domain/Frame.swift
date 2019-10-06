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

class Frame: NSObject {
    let items: [Item]

    init(items: [Item]) {
        self.items = items
    }
}

extension Frame {
    convenience init? (with codingData: OpenHABSitemap.CodingData?) {
        guard let widgets = codingData?.page.widgets else { return nil }
        self.init(items: widgets.compactMap { Item(with: $0.item) })
    }
}
