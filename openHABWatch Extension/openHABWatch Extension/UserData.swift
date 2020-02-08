// Copyright (c) 2010-2020 Contributors to the openHAB project
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

// swiftlint:disable file_types_order
extension OpenHABCoreWatch.Future where Value == ObservableOpenHABSitemapPage.CodingData {
    func trafo() -> OpenHABCoreWatch.Future<ObservableOpenHABSitemapPage> {
        transformed { data in
            data.openHABSitemapPage
        }
    }
}

final class UserData: ObservableObject {
    @Published var widgets: [ObservableOpenHABWidget] = []
    @Published var showAlert = false
    @Published var errorDescription = ""

    let decoder = JSONDecoder()

    var openHABSitemapPage: ObservableOpenHABSitemapPage?

    private var commandOperation: Alamofire.Request?
    private var currentPageOperation: Alamofire.Request?

    // Demo
    init() {
        decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)

        let data = PreviewConstants.sitemapJson

        do {
            // Self-executing closure
            // Inspired by https://www.swiftbysundell.com/posts/inline-types-and-functions-in-swift
            openHABSitemapPage = try {
                let sitemapPageCodingData = try data.decoded(as: ObservableOpenHABSitemapPage.CodingData.self)
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

    init(url: URL?, refresh: Bool = true) {
        loadPage(url: url,
                 longPolling: true,
                 refresh: refresh)
    }

    init(urlString: String, refresh: Bool = true, sitemapName: String = "watch") {
        loadPage(urlString: urlString,
                 longPolling: false,
                 refresh: refresh,
                 sitemapName: sitemapName)
    }

    func loadPage(urlString: String,
                  longPolling: Bool,
                  refresh: Bool,
                  sitemapName: String = "watch") {
        let url = Endpoint.watchSitemap(openHABRootUrl: urlString, sitemapName: sitemapName).url
        loadPage(url: url, longPolling: longPolling, refresh: refresh)
    }

    func request(_ endpoint: Endpoint) -> OpenHABCoreWatch.Future<Data> {
        // Start by constructing a Promise, that will later be
        // returned as a Future
        let promise = Promise<Data>()

        // Immediately reject the promise in case the passed
        // endpoint can't be converted into a valid URL
        guard let url = endpoint.url else {
            promise.reject(with: NetworkingError.invalidURL)
            return promise
        }

        if currentPageOperation != nil {
            currentPageOperation?.cancel()
            currentPageOperation = nil
        }

        currentPageOperation = NetworkConnection.page(url: url,
                                                      longPolling: true,
                                                      openHABVersion: 2) { [weak self] response in
            guard self != nil else { return }

            switch response.result {
            case .success:
                os_log("openHAB 2", log: OSLog.remoteAccess, type: .info)
                promise.resolve(with: response.result.value ?? Data())

            case let .failure(error):
                os_log("On LoadPage %{PUBLIC}@ code: %d ", log: .remoteAccess, type: .error, error.localizedDescription, response.response?.statusCode ?? 0)
                promise.reject(with: error)
            }
        }
        currentPageOperation?.resume()

        return promise
    }

    func loadPage(_ endpoint: Endpoint) {
        request(endpoint)
            .decoded(as: ObservableOpenHABSitemapPage.CodingData.self)
            .trafo()
            .observe { result in
                switch result {
                case let .failure(error):
                    os_log("On LoadPage %{PUBLIC}@", log: .remoteAccess, type: .error, error.localizedDescription)
                case let .success(page):
                    self.openHABSitemapPage = page
                }
            }
    }

    func loadPage(url: URL?,
                  longPolling: Bool,
                  refresh: Bool) {
        if currentPageOperation != nil {
            currentPageOperation?.cancel()
            currentPageOperation = nil
        }

        currentPageOperation = NetworkConnection.page(url: url,
                                                      longPolling: longPolling,
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
                            let sitemapPageCodingData = try data.decoded(as: ObservableOpenHABSitemapPage.CodingData.self)
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

                self.showAlert = self.widgets.isEmpty ? true : false
                if refresh { self.loadPage(url: url,
                                           longPolling: true,
                                           refresh: true) }

            case let .failure(error):
                os_log("On LoadPage %{PUBLIC}@ code: %d ", log: .remoteAccess, type: .error, error.localizedDescription, response.response?.statusCode ?? 0)
                self.errorDescription = error.localizedDescription
                self.widgets = []
                self.showAlert = true
            }
        }
        currentPageOperation?.resume()
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
