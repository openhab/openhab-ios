// Copyright (c) 2010-2025 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

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

    private var commandOperation: URLSessionTask?
    private var currentPageOperation: URLSessionTask?
    private var cancellables = Set<AnyCancellable>()

    private let logger = Logger(subsystem: "org.openhab.app.watchkitapp", category: "UserData")

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
            self?.sendCommand(item, command: command)
        }
    }

    init(sitemapName: String = "watch") {
        updateNetwork()
        NetworkTracker.shared.$activeConnection
            .receive(on: DispatchQueue.main)
            .sink { [weak self] activeConnection in
                if let activeConnection {
                    self?.logger.info("openHABTracked: \(activeConnection.configuration.url)")

                    if !ObservableOpenHABDataObject.shared.haveReceivedAppContext {
                        AppMessageService.singleton.requestApplicationContext()
                        self?.errorDescription = NSLocalizedString("settings_not_received", comment: "")
                        self?.showAlert = true
                        return
                    }

                    ObservableOpenHABDataObject.shared.openHABRootUrl = activeConnection.configuration.url
                    ObservableOpenHABDataObject.shared.openHABVersion = activeConnection.version

                    let url = Endpoint.watchSitemap(openHABRootUrl: activeConnection.configuration.url, sitemapName: ObservableOpenHABDataObject.shared.sitemapForWatch).url
                    self?.loadPage(url: url, longPolling: false, refresh: true)
                }
            }
            .store(in: &cancellables)

        ObservableOpenHABDataObject.shared.objectRefreshed.sink { _ in
            // New settings updates from the phone app to start a reconnect
            self.logger.info("Settings update received, starting reconnect")
            self.updateNetwork()
        }
        .store(in: &cancellables)
    }

    func updateNetwork() {
        if !ObservableOpenHABDataObject.shared.localUrl.isEmpty || !ObservableOpenHABDataObject.shared.remoteUrl.isEmpty {
            let connection1 = ConnectionConfiguration(
                url: ObservableOpenHABDataObject.shared.localUrl,
                priority: 0
            )
            let connection2 = ConnectionConfiguration(
                url: ObservableOpenHABDataObject.shared.remoteUrl,
                priority: 1
            )
            NetworkTracker.shared.startTracking(connectionConfigurations: [connection1, connection2], username: ObservableOpenHABDataObject.shared.openHABUsername, password: ObservableOpenHABDataObject.shared.openHABPassword, alwaysSendBasicAuth: ObservableOpenHABDataObject.shared.openHABAlwaysSendCreds, ignoreSSLVerification: ObservableOpenHABDataObject.shared.ignoreSSL)
        }
    }

    func loadPage(url: URL? = nil, longPolling: Bool, refresh: Bool) {
        logger.info("Loading page \(url?.absoluteString ?? "") longPolling \(longPolling) refresh \(refresh)")

        // Cancel any running operation
        if let currentPageOperation, currentPageOperation.state == .running {
            currentPageOperation.cancel()
        }

        currentPageOperation = NetworkTracker.shared.httpClient?.loadSitemapData(url: url, longPolling: longPolling, refresh: refresh) { [weak self] data, error in
            guard let self else { return }
            currentPageOperation = nil

            if let error = error as? URLError, error.code == .cancelled {
                logger.info("Task was canceled")
                return
            }

            var errorString: String?

            if error != nil || data == nil {
                errorString = error?.localizedDescription ?? "No data received"
            }

            if errorString == nil {
                do {
                    let sitemapPageCodingData = try data!.decoded(as: ObservableOpenHABSitemapPage.CodingData.self)
                    openHABSitemapPage = sitemapPageCodingData.openHABSitemapPage
                } catch {
                    logger.error("Decoding error: \(error.localizedDescription)")
                    errorString = error.localizedDescription
                }
            }

            if let errorString {
                DispatchQueue.main.async {
                    self.logger.error("On LoadPage \"\(errorString)\"")
                    self.errorDescription = errorString
                    self.widgets = []
                    self.showAlert = true
                }
                return
            }

            // Configures then sendCommand closure (existing logic)
            openHABSitemapPage?.sendCommand = { [weak self] item, command in
                self?.sendCommand(item, command: command)
            }

            // Always update UI on the main thread
            DispatchQueue.main.async {
                self.widgets = self.openHABSitemapPage?.widgets ?? []
                self.showAlert = self.widgets.isEmpty
                if refresh {
                    self.loadPage(url: url, longPolling: true, refresh: true)
                }
            }
        }
    }

    func sendCommand(_ item: OpenHABItem?, command: String?) {
        if let commandOperation, commandOperation.state == .running {
            commandOperation.cancel()
        }
        if let item, let command {
            commandOperation = NetworkTracker.shared.httpClient?.sendCommand(itemName: item.name, command: command) { _, error in
                if error != nil {
                    self.logger.error("Error sending command \(command) to \(item.name): \(error!.localizedDescription)")
                }
                self.commandOperation = nil
            }
        }
    }

    func refreshUrl() {
        if ObservableOpenHABDataObject.shared.haveReceivedAppContext, !ObservableOpenHABDataObject.shared.openHABRootUrl.isEmpty {
            showAlert = false
            let url = Endpoint.watchSitemap(openHABRootUrl: ObservableOpenHABDataObject.shared.openHABRootUrl, sitemapName: ObservableOpenHABDataObject.shared.sitemapForWatch).url
            loadPage(url: url, longPolling: false, refresh: true)
        }
    }
}
