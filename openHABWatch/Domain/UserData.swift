// Copyright (c) 2010-2024 Contributors to the openHAB project
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
import OpenHABCore
import os.log
import SwiftUI

// swiftlint:disable:next file_types_order
extension OpenHABCore.Future where Value == ObservableOpenHABSitemapPage.CodingData {
    func trafo() -> OpenHABCore.Future<ObservableOpenHABSitemapPage> {
        transformed { data in
            data.openHABSitemapPage
        }
    }
}

final class UserData: ObservableObject {
    static let shared = UserData()
    @Published var widgets: [ObservableOpenHABWidget] = []
    @Published var showAlert = false
    @Published var errorDescription = ""
    @Published var showCertificateAlert = false
    @Published var certificateErrorDescription = ""

    let decoder = JSONDecoder()

    var openHABSitemapPage: ObservableOpenHABSitemapPage?

    private var commandOperation: Alamofire.Request?
    private var currentPageOperation: Alamofire.Request?
    private var tracker: OpenHABWatchTracker?
    private var dataObjectCancellable: AnyCancellable?
    
    private let logger = Logger(subsystem: "org.openhab.app.watch", category: "UserData")

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
            logger.error("Should not throw \(error.localizedDescription)")
        }

        widgets = openHABSitemapPage?.widgets ?? []

        openHABSitemapPage?.sendCommand = { [weak self] item, command in
            self?.sendCommand(item, commandToSend: command)
        }
    }

    init(url: URL?, refresh: Bool = true) {
        loadPage(
            url: url,
            longPolling: true,
            refresh: refresh
        )
    }

    init(url: URL?) {
        tracker = OpenHABWatchTracker()
        tracker?.delegate = self
    }

    init(sitemapName: String = "watch") {
        tracker = OpenHABWatchTracker()
        tracker?.delegate = self
        tracker?.start()

        dataObjectCancellable = ObservableOpenHABDataObject.shared.objectRefreshed.sink { _ in
            // New settings updates from the phone app to start a reconnect
            self.logger.info("Settings update received, starting reconnect")
            self.refreshUrl()
        }
        refreshUrl()
    }

    func loadPage(url: URL?,
                  longPolling: Bool,
                  refresh: Bool) {
        if currentPageOperation != nil {
            currentPageOperation?.cancel()
            currentPageOperation = nil
        }

        currentPageOperation = NetworkConnection.page(
            url: url,
            longPolling: longPolling
        ) { [weak self] response in
            guard let self else { return }

            switch response.result {
            case let .success(data):
                logger.info("Page loaded with success")
                do {
                    // Self-executing closure
                    // Inspired by https://www.swiftbysundell.com/posts/inline-types-and-functions-in-swift
                    openHABSitemapPage = try {
                        let sitemapPageCodingData = try data.decoded(as: ObservableOpenHABSitemapPage.CodingData.self)
                        return sitemapPageCodingData.openHABSitemapPage
                    }()
                } catch {
                    logger.error("Should not throw \(error.localizedDescription)")
                }

                openHABSitemapPage?.sendCommand = { [weak self] item, command in
                    self?.sendCommand(item, commandToSend: command)
                }

                widgets = openHABSitemapPage?.widgets ?? []

                showAlert = widgets.isEmpty ? true : false
                if refresh { loadPage(
                    url: url,
                    longPolling: true,
                    refresh: true
                ) }

            case let .failure(error):
                logger.error("On LoadPage \"\(error.localizedDescription)\" with code: \(response.response?.statusCode ?? 0)")
                errorDescription = error.localizedDescription
                widgets = []
                showAlert = true
            }
        }
        currentPageOperation?.resume()
    }

    func sendCommand(_ item: OpenHABItem?, commandToSend command: String?) {
        if commandOperation != nil {
            commandOperation?.cancel()
            commandOperation = nil
        }
        if let item, let command {
            commandOperation = NetworkConnection.sendCommand(item: item, commandToSend: command)
            commandOperation?.resume()
        }
    }

    func refreshUrl() {
        if ObservableOpenHABDataObject.shared.haveReceivedAppContext {
            showAlert = false
            tracker?.selectUrl()
        }
    }

}

extension UserData: OpenHABWatchTrackerDelegate {
    func openHABTracked(_ openHABUrl: URL?, version: Int) {
        guard let urlString = openHABUrl?.absoluteString else { return }
        logger.error("openHABTracked: \(urlString)")

        if !ObservableOpenHABDataObject.shared.haveReceivedAppContext {
            AppMessageService.singleton.requestApplicationContext()
            errorDescription = NSLocalizedString("settings_not_received", comment: "")
            showAlert = true
            return
        }

        ObservableOpenHABDataObject.shared.openHABRootUrl = urlString
        ObservableOpenHABDataObject.shared.openHABVersion = version

        let url = Endpoint.watchSitemap(openHABRootUrl: urlString, sitemapName: ObservableOpenHABDataObject.shared.sitemapForWatch).url
        loadPage(url: url, longPolling: false, refresh: true)
    }

    func openHABTrackingProgress(_ message: String?) {
        logger.error("openHABTrackingProgress: \(message ?? "")")
    }

    func openHABTrackingError(_ error: Error) {
        logger.error("openHABTrackingError: \(error.localizedDescription)")
    }
}
