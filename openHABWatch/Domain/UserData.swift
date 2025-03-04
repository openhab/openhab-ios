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

//// Copyright (c) 2010-2025 Contributors to the openHAB project
////
//// See the NOTICE file(s) distributed with this work for additional
//// information.
////
//// This program and the accompanying materials are made available under the
//// terms of the Eclipse Public License 2.0 which is available at
//// http://www.eclipse.org/legal/epl-2.0
////
//// SPDX-License-Identifier: EPL-2.0
//
// import Combine
// import Foundation
// import OpenHABCore
// import os.log
// import SwiftUI
//
// final class UserData: ObservableObject {
//    static let shared = UserData()
//    @Published var widgets: [OpenHABWidget] = []
//    @Published var showAlert = false
//    @Published var errorDescription = ""
//    @Published var showCertificateAlert = false
//    @Published var certificateErrorDescription = ""
//    let decoder = JSONDecoder()
//
//    var openHABSitemapPage: OpenHABPage?
//
//    private var commandOperation: URLSessionTask?
//    private var currentPageOperation: URLSessionTask?
//    private var activePageTask: Task<Void, Never>?
//    private var cancellables = Set<AnyCancellable>()
//
//    private let logger = Logger(subsystem: "org.openhab.app.watchkitapp", category: "UserData")
//
//    // Add property near other published properties
//    var currentClient: HTTPClient?
//
//    // Add to init() after decoder setup
//    init() {
//        decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)
//
//        let data = PreviewConstants.sitemapJson
//
//        do {
//            // Self-executing closure
//            // Inspired by https://www.swiftbysundell.com/posts/inline-types-and-functions-in-swift
//            openHABSitemapPage = try {
//                let sitemapPageCodingData = try data.decoded(as: OpenHABPage.CodingData.self)
//                return sitemapPageCodingData.openHABSitemapPage
//            }()
//        } catch {
//            logger.error("Should not throw \(error.localizedDescription)")
//        }
//
//        widgets = openHABSitemapPage?.widgets ?? []
//
//        openHABSitemapPage?.sendCommand = { [weak self] item, command in
//            self?.sendCommand(item, command: command)
//        }
//    }
//
//    init(sitemapName: String = "watch") {
//        NotificationCenter.default.addObserver(
//            forName: .evaluateServerTrust,
//            object: nil,
//            queue: .main
//        ) { [weak self] notification in
//            guard let self,
//                  let summary = notification.userInfo?["summary"] as? String,
//                  let domain = notification.userInfo?["domain"] as? String,
//                  let client = notification.object as? HTTPClient else { return }
//
//            certificateErrorDescription = String(format: NSLocalizedString("ssl_certificate_invalid", comment: ""), summary, domain)
//            currentClient = client
//            DispatchQueue.main.async {
//                self.showCertificateAlert = true
//            }
//        }
//        NotificationCenter.default.addObserver(
//            forName: .evaluateCertificateMismatch,
//            object: nil,
//            queue: .main
//        ) { [weak self] notification in
//            guard let self,
//                  let summary = notification.userInfo?["summary"] as? String,
//                  let domain = notification.userInfo?["domain"] as? String,
//                  let client = notification.object as? HTTPClient else { return }
//
//            certificateErrorDescription = String(format: NSLocalizedString("ssl_certificate_no_match", comment: ""), summary, domain)
//            currentClient = client
//            DispatchQueue.main.async {
//                self.showCertificateAlert = true
//            }
//        }
//
//        NotificationCenter.default.addObserver(
//            forName: .acceptedServerCertificatesChanged,
//            object: nil,
//            queue: nil
//        ) { _ in
//            NetworkTracker.shared.restartTracking()
//        }
//
//        updateNetwork()
//
//        NetworkTracker.shared.$activeConnection
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] activeConnection in
//                if let activeConnection {
//                    self?.logger.info("openHABTracked: \(activeConnection.configuration.url)")
//
//                    if !ObservableOpenHABDataObject.shared.haveReceivedAppContext {
//                        AppMessageService.singleton.requestApplicationContext()
//                        self?.errorDescription = NSLocalizedString("settings_not_received", comment: "")
//                        self?.showAlert = true
//                        return
//                    }
//
//                    ObservableOpenHABDataObject.shared.openHABRootUrl = activeConnection.configuration.url
//                    ObservableOpenHABDataObject.shared.openHABVersion = activeConnection.version
//
//                    // TODE Update RootURL
//                    self?.loadPage(sitemapName: ObservableOpenHABDataObject.shared.sitemapForWatch, longPolling: false, refresh: true)
//                }
//            }
//            .store(in: &cancellables)
//
//        ObservableOpenHABDataObject.shared.objectRefreshed.sink { _ in
//            // New settings updates from the phone app to start a reconnect
//            self.logger.info("Settings update received, starting reconnect")
//            self.updateNetwork()
//        }
//        .store(in: &cancellables)
//    }
//
//    func updateNetwork() {
//        if !ObservableOpenHABDataObject.shared.localUrl.isEmpty || !ObservableOpenHABDataObject.shared.remoteUrl.isEmpty {
//            let connection1 = ConnectionConfiguration(
//                url: ObservableOpenHABDataObject.shared.localUrl,
//                priority: 0
//            )
//            let connection2 = ConnectionConfiguration(
//                url: ObservableOpenHABDataObject.shared.remoteUrl,
//                priority: 1
//            )
//            NetworkTracker.shared.startTracking(connectionConfigurations: [connection1, connection2], username: ObservableOpenHABDataObject.shared.openHABUsername, password: ObservableOpenHABDataObject.shared.openHABPassword, alwaysSendBasicAuth: ObservableOpenHABDataObject.shared.openHABAlwaysSendCreds, ignoreSSLVerification: ObservableOpenHABDataObject.shared.ignoreSSL)
//        }
//    }
//
//    func loadPage(sitemapName: String, longPolling: Bool, refresh: Bool) {
//        logger.info("Loading page \(sitemapName) longPolling \(longPolling) refresh \(refresh)")
//
//        // Cancel the active task if it is running
//        activePageTask?.cancel()
//
//        activePageTask = Task { [weak self] in
//            guard let self else { return }
//            do {
//                guard let openAPIService = NetworkTracker.shared.openApiService else { return }
//                openHABSitemapPage = try await openAPIService.pollDataForPage(sitemapname: sitemapName, longPolling: longPolling)
//                // Configures then sendCommand closure (existing logic)
//                openHABSitemapPage?.sendCommand = { [weak self] item, command in
//                    self?.sendCommand(item, command: command)
//                }
//                // Always update UI on the main thread
//                await MainActor.run {
//                    self.widgets = self.openHABSitemapPage?.widgets ?? []
//                    self.showAlert = self.widgets.isEmpty
//                    if refresh {
//                        self.loadPage(sitemapName: sitemapName, longPolling: true, refresh: true)
//                    }
//                }
//            } catch {
//                if Task.isCancelled {
//                    logger.info("Task was canceled")
//                } else {
//                    logger.error("Polling failed with error \(error)")
//                    await MainActor.run {
//                        self.logger.error("On LoadPage \"\(error.localizedDescription)\"")
//                        self.widgets = []
//                        self.showAlert = true
//                    }
//                }
//            }
//        }
//    }
//
//    func sendCommand(_ item: OpenHABItem?, command: String?) {
//        if let commandOperation, commandOperation.state == .running {
//            commandOperation.cancel()
//        }
//        if let item, let command {
//            Task {
//                do {
//                    try await NetworkTracker.shared.openApiService?.sendItemCommand(itemname: item.name, command: command)
//                } catch {
//                    logger.error("Error sending command \(command) to \(item.name): \(error.localizedDescription)")
//                }
//            }
//        }
//    }
//
//    func refreshUrl() {
//        if ObservableOpenHABDataObject.shared.haveReceivedAppContext, !ObservableOpenHABDataObject.shared.openHABRootUrl.isEmpty {
//            showAlert = false
//            // TODO: Update
//            loadPage(sitemapName: ObservableOpenHABDataObject.shared.sitemapForWatch, longPolling: false, refresh: true)
//        }
//    }
// }

import Foundation
import OpenHABCore
import os.log
import SwiftUI

@MainActor
final class UserData: ObservableObject {
    static let shared = UserData()

    @Published var widgets: [OpenHABWidget] = []
    @Published var showAlert = false
    @Published var errorDescription = ""
    @Published var showCertificateAlert = false
    @Published var certificateErrorDescription = ""

    var openHABSitemapPage: OpenHABPage?
    var currentClient: HTTPClient?

    private let logger = Logger(subsystem: "org.openhab.app.watchkitapp", category: "UserData")

    init(sitemapName: String = "watch") {
        Task {
            await observeNetworkChanges()
        }

        NotificationCenter.default.addObserver(
            forName: .evaluateServerTrust,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let summary = notification.userInfo?["summary"] as? String,
                  let domain = notification.userInfo?["domain"] as? String,
                  let client = notification.object as? HTTPClient else { return }
            DispatchQueue.main.async {
                self.certificateErrorDescription = String(format: NSLocalizedString("ssl_certificate_invalid", comment: ""), summary, domain)
                self.currentClient = client
                self.showCertificateAlert = true
            }
        }

        NotificationCenter.default.addObserver(
            forName: .evaluateCertificateMismatch,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let summary = notification.userInfo?["summary"] as? String,
                  let domain = notification.userInfo?["domain"] as? String,
                  let client = notification.object as? HTTPClient else { return }
            DispatchQueue.main.async {
                self.certificateErrorDescription = String(format: NSLocalizedString("ssl_certificate_no_match", comment: ""), summary, domain)
                self.currentClient = client
                self.showCertificateAlert = true
            }
        }

        NotificationCenter.default.addObserver(
            forName: .acceptedServerCertificatesChanged,
            object: nil,
            queue: nil
        ) { _ in
            NetworkTracker.shared.restartTracking()
        }
    }

    /// Observes network connection changes and updates state
    private func observeNetworkChanges() async {
        for await activeConnection in NetworkTracker.shared.activeConnectionStream() {
            guard let activeConnection else { continue }

            logger.info("openHABTracked: \(activeConnection.configuration.url)")

            if !ObservableOpenHABDataObject.shared.haveReceivedAppContext {
                AppMessageService.singleton.requestApplicationContext()
                errorDescription = NSLocalizedString("settings_not_received", comment: "")
                showAlert = true
                continue
            }

            ObservableOpenHABDataObject.shared.openHABRootUrl = activeConnection.configuration.url
            ObservableOpenHABDataObject.shared.openHABVersion = activeConnection.version

            await loadPage(sitemapName: ObservableOpenHABDataObject.shared.sitemapForWatch, longPolling: false, refresh: true)
        }
    }

    func updateNetwork() async {
        if !ObservableOpenHABDataObject.shared.localUrl.isEmpty || !ObservableOpenHABDataObject.shared.remoteUrl.isEmpty {
            let connection1 = ConnectionConfiguration(
                url: ObservableOpenHABDataObject.shared.localUrl,
                priority: 0
            )
            let connection2 = ConnectionConfiguration(
                url: ObservableOpenHABDataObject.shared.remoteUrl,
                priority: 1
            )

            NetworkTracker.shared.startTracking(
                connectionConfigurations: [connection1, connection2],
                username: ObservableOpenHABDataObject.shared.openHABUsername,
                password: ObservableOpenHABDataObject.shared.openHABPassword,
                alwaysSendBasicAuth: ObservableOpenHABDataObject.shared.openHABAlwaysSendCreds,
                ignoreSSLVerification: ObservableOpenHABDataObject.shared.ignoreSSL
            )
        }
    }

    func loadPage(sitemapName: String, longPolling: Bool, refresh: Bool) async {
        logger.info("Loading page \(sitemapName) longPolling \(longPolling) refresh \(refresh)")

        do {
            guard let openAPIService = NetworkTracker.shared.openApiService else { return }
            openHABSitemapPage = try await openAPIService.pollDataForPage(sitemapname: sitemapName, longPolling: longPolling)

            openHABSitemapPage?.sendCommand = { [weak self] item, command in
                Task { await self?.sendCommand(item, command: command) }
            }

            widgets = openHABSitemapPage?.widgets ?? []
            showAlert = widgets.isEmpty

            if refresh {
                await loadPage(sitemapName: sitemapName, longPolling: true, refresh: true)
            }
        } catch {
            logger.error("Polling failed with error \(error.localizedDescription)")
            widgets = []
            showAlert = true
        }
    }

    func sendCommand(_ item: OpenHABItem?, command: String?) async {
        guard let item, let command else { return }

        do {
            try await NetworkTracker.shared.openApiService?.sendItemCommand(itemname: item.name, command: command)
        } catch {
            logger.error("Error sending command \(command) to \(item.name): \(error.localizedDescription)")
        }
    }

    func refreshUrl() async {
        guard ObservableOpenHABDataObject.shared.haveReceivedAppContext,
              !ObservableOpenHABDataObject.shared.openHABRootUrl.isEmpty else { return }

        showAlert = false
        await loadPage(sitemapName: ObservableOpenHABDataObject.shared.sitemapForWatch, longPolling: false, refresh: true)
    }
}
