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

import Combine
import SwiftUI

let sitemapData: [Item] = [Item(name: "Light0",
                                label: "Light Ground Floor",
                                state: true,
                                link: "http://192.168.2.15:8081/icon/switch?state=OFF")!,
                           Item(name: "Light1",
                                label: "Light First Floor",
                                state: false,
                                link: "http://192.168.2.15:8081/icon/switch?state=ON")!,
                           Item(name: "Light2",
                                label: "Light Second Floor",
                                state: false,
                                link: "http://192.168.2.15:8081/icon/light?state=OFF")!,
                           Item(name: "Light3",
                                label: "Light Third Floor",
                                state: false,
                                link: "http://192.168.2.15:8081/icon/switch?state=OFF")!]

final class UserData: ObservableObject {
    @Published var items: [Item] = sitemapData
}
