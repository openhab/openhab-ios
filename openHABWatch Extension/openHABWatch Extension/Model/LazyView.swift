// Copyright (c) 2010-2021 Contributors to the openHAB project
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

// https://medium.com/better-programming/swiftui-navigation-links-and-the-common-pitfalls-faced-505cbfd8029b
struct LazyView<Content: View>: View {
    let build: () -> Content

    var body: Content {
        build()
    }

    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
}
