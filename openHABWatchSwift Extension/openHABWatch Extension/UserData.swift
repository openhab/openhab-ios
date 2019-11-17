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

import Alamofire
import Combine
import Foundation
import OpenHABCoreWatch
import os.log
import SwiftUI

// swiftlint:disable line_length
let sitemapJson = """
{"id":"watch","title":"watch","link":"http://192.168.2.15:8081/rest/sitemaps/watch/watch","leaf":true,"timeout":false,"widgets":[{"widgetId":"00","type":"Switch","label":"Licht Keller WC Decke","icon":"switch","mappings":[],"item":{"link":"http://192.168.2.15:8081/rest/items/lcnLightSwitch6_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch6_1","label":"Licht Keller WC Decke","tags":["Lighting"],"groupNames":["gKellerLicht","gLcn"]},"widgets":[]},{"widgetId":"01","type":"Switch","label":"Licht Oberlicht","icon":"switch","mappings":[],"item":{"link":"http://192.168.2.15:8081/rest/items/lcnLightSwitch14_1","state":"OFF","editable":false,"type":"Switch","name":"lcnLightSwitch14_1","label":"Licht Oberlicht","tags":["Lighting"],"groupNames":["gEGLicht","G_PresenceSimulation","gLcn"]},"widgets":[]}]}
""".data(using: .utf8)!

final class UserData: ObservableObject {
    @Published var widgets: [ObservableOpenHABWidget] = []

    let decoder = JSONDecoder()

    var openHABSitemapPage: ObservableOpenHABSitemapPage?

    private var commandOperation: Alamofire.Request?

    init() {
        decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)

        let data = sitemapJson

        do {
            // Self-executing closure
            // Inspired by https://www.swiftbysundell.com/posts/inline-types-and-functions-in-swift
            openHABSitemapPage = try {
                let sitemapPageCodingData = try data.decoded() as ObservableOpenHABSitemapPage.CodingData
                return sitemapPageCodingData.openHABSitemapPage
            }()
        } catch {
            os_log("Should not throw %{PUBLIC}@", log: OSLog.remoteAccess, type: .error, error.localizedDescription)
        }

        widgets = openHABSitemapPage?.widgets ?? []

        openHABSitemapPage?.sendCommand = { [weak self] item, command in
            self?.sendCommand(item, commandToSend: command)
        }
    }

    init(urlString: String) {
        commandOperation = NetworkConnection.page(url: Endpoint.watchSitemap(openHABRootUrl: urlString, sitemapName: "watch").url,
                                                  longPolling: false,
                                                  openHABVersion: 2) { [weak self] response in
            guard let self = self else { return }

            switch response.result {
            case .success:
                os_log("Page loaded with success", log: OSLog.remoteAccess, type: .info)

                if let data = response.result.value {
                    // Newer versions talk JSON!
                    os_log("openHAB 2", log: OSLog.remoteAccess, type: .info)
                    do {
                        // Self-executing closure
                        // Inspired by https://www.swiftbysundell.com/posts/inline-types-and-functions-in-swift
                        self.openHABSitemapPage = try {
                            let sitemapPageCodingData = try data.decoded() as ObservableOpenHABSitemapPage.CodingData
                            return sitemapPageCodingData.openHABSitemapPage
                        }()
                    } catch {
                        os_log("Should not throw %{PUBLIC}@", log: OSLog.remoteAccess, type: .error, error.localizedDescription)
                    }
                }

                self.openHABSitemapPage?.sendCommand = { [weak self] item, command in
                    self?.sendCommand(item, commandToSend: command)
                }

                self.widgets = self.openHABSitemapPage?.widgets ?? []

            case .failure:
                break
            }
        }
        commandOperation?.resume()
    }

    func sendCommand(_ item: OpenHABItem?, commandToSend command: String?) {
        if commandOperation != nil {
            commandOperation?.cancel()
            commandOperation = nil
        }
        if let item = item, let command = command {
            commandOperation = NetworkConnection.sendCommand(item: item, commandToSend: command)
            commandOperation?.resume()
        }
    }
}
