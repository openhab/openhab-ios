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
import os.log
import SwiftUI

let sitemapJson = """
{"name":"watch","label":"watch","link":"https://192.168.2.15:8444/rest/sitemaps/watch",
    "homepage":
{"id":"watch","title":"watch","link":"https://192.168.2.15:8444/rest/sitemaps/watch/watch","leaf":false,"timeout":false,
            "widgets":[
                {"widgetId":"00","type":"Switch","label":"Licht Keller WC Decke","icon":"switch","mappings":[],
            "item":{"link":"https://192.168.2.15:8444/rest/items/lcnLightSwitch6_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch6_1","label":"Licht Keller WC Decke","tags":["Lighting"],"groupNames":["gKellerLicht","gLcn"]},"widgets":[]},
                {"widgetId":"01","type":"Switch","label":"Licht Oberlicht","icon":"switch","mappings":[],"item":{"link":"https://192.168.2.15:8444/rest/items/lcnLightSwitch14_1","state":"ON","editable":false,"type":"Switch","name":"lcnLightSwitch14_1","label":"Licht Oberlicht","tags":["Lighting"],"groupNames":["gEGLicht","G_PresenceSimulation","gLcn"]},"widgets":[]}
            ]
        }
    }
""".data(using: .utf8)!

final class UserData: ObservableObject {
    @Published var items: [NewOpenHABWidget] = []

    let decoder = JSONDecoder()

    var openHABSitemapPage: OpenHABSitemapPage<NewOpenHABWidget>?

    init() {
        decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)

        let data = sitemapJson

        items = openHABSitemapPage?.widgets ?? []

        do {
            // Self-executing closure
            // Inspired by https://www.swiftbysundell.com/posts/inline-types-and-functions-in-swift
            openHABSitemapPage = try {
                let sitemapPageCodingData = try data.decoded() as OpenHABSitemapPage<NewOpenHABWidget>.CodingData
                return sitemapPageCodingData.openHABSitemapPage
            }()
        } catch {
            os_log("Should not throw %{PUBLIC}@", log: OSLog.remoteAccess, type: .error, error.localizedDescription)
        }

    }

}
