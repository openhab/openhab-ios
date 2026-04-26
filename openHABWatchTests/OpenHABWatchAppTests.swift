// Copyright (c) 2010-2026 Contributors to the openHAB project
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
import OpenHABCore
import Testing

// swiftlint:disable line_length
struct OpenHABWatchAppTests {
    private let watchSitemapJSON = Data("""
    {"name":"watch","label":"watch","link":"https://192.168.2.15:8444/rest/sitemaps/watch","homepage":{"id":"watch","title":"watch","link":"https://192.168.2.15:8444/rest/sitemaps/watch/watch","leaf":false,"timeout":false,"widgets":[{"widgetId":"00","type":"Frame","label":"Ground floor","icon":"frame","mappings":[],"widgets":[{"widgetId":"0000","type":"Switch","label":"Licht Oberlicht","icon":"switch","mappings":[],"item":{"link":"https://192.168.2.15:8444/rest/items/lcnLightSwitch14_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch14_1","label":"Licht Oberlicht","tags":["Lighting"],"groupNames":["G_PresenceSimulation","gLcn"]},"widgets":[]}]}]}}
    """.utf8)

    @Test("Watch sitemap JSON decodes into SitemapDTO")
    func decodeWatchSitemapDTO() throws {
        let decoder = JSONDecoder()
        let dto = try decoder.decode(Components.Schemas.SitemapDTO.self, from: watchSitemapJSON)

        #expect(dto.name == "watch")
        #expect(dto.homepage?.link == "https://192.168.2.15:8444/rest/sitemaps/watch/watch")
        #expect(dto.homepage?.widgets?.first?._type == "Frame")
    }

    @Test("Watch sitemap DTO maps into OpenHABPage model")
    func mapWatchSitemapPageModel() throws {
        let decoder = JSONDecoder()
        let dto = try decoder.decode(Components.Schemas.SitemapDTO.self, from: watchSitemapJSON)
        let page = try #require(OpenHABPage(dto.homepage))

        #expect(page.title == "watch")
        #expect(page.link == "https://192.168.2.15:8444/rest/sitemaps/watch/watch")
        #expect(page.widgets.first?.type == .frame)
        #expect(page.widgets.first?.widgets.first?.item?.name == "lcnLightSwitch14_1")
    }
}

// swiftlint:enable line_length
