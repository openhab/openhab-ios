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
            openHABSitemapPage = try await NetworkTracker.shared.pollDataForPage(sitemapname: sitemapName, longPolling: longPolling)

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
            try await NetworkTracker.shared.send(to: item, command: command)
        } catch {
            logger.info("Could not send command \(command) to \(item.name)")
        }
    }

    func refreshUrl() async {
        guard ObservableOpenHABDataObject.shared.haveReceivedAppContext,
              !ObservableOpenHABDataObject.shared.openHABRootUrl.isEmpty else { return }

        showAlert = false
        await loadPage(sitemapName: ObservableOpenHABDataObject.shared.sitemapForWatch, longPolling: false, refresh: true)
    }
}
