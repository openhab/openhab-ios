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

@MainActor
final class UserData: ObservableObject {
    static let shared = UserData()

    @Published var widgets: [OpenHABWidget] = []
    @Published var showAlert = false
    @Published var errorDescription = ""
    @Published var showCertificateAlert = false
    @Published var certificateErrorDescription = ""
    @Published var isLoadingSitemap = false

    private var pageHandlingTask: Task<Void, Never>?
    @Published var isPolling = false

    var openHABSitemapPage: OpenHABPage?
    var currentClient: HTTPClient?

    private let logger = Logger(subsystem: "org.openhab.app.watchkitapp", category: "UserData")

    private var cancellables = Set<AnyCancellable>()

    #if DEBUG
    init(preview: Bool = false) {
        let data = PreviewConstants.sitemapJson
        do {
            let sitemapPage = try data.decoded(as: Components.Schemas.PageDTO.self)
            openHABSitemapPage = OpenHABPage(sitemapPage)
            widgets = openHABSitemapPage?.widgets ?? []
            openHABSitemapPage?.sendCommand = { [weak self] item, command in
                Task { await self?.sendCommand(item, command: command) }
            }
        } catch {
            logger.error("Should not throw \(error.localizedDescription)")
        }
    }
    #endif

    init() {
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

        AppSettings.shared.$haveReceivedAppContext
            .removeDuplicates()
            .filter { $0 == true }
            .sink { [weak self] _ in
                Task {
                    await self?.updateNetwork()
                }
            }
            .store(in: &cancellables)

        AppSettings.shared.$sitemapForWatch
            .removeDuplicates()
            .sink { [weak self] newValue in
                guard !newValue.isEmpty else { return }
                self?.startPageHandling(sitemapName: newValue)
            }
            .store(in: &cancellables)

        Task {
            await observeNetworkChanges()
        }
    }

    /// Observes network connection changes and updates state
    private func observeNetworkChanges() async {
        for await activeConnection in NetworkTracker.shared.activeConnectionStream() {
            guard let activeConnection else { continue }

            logger.info("openHABTracked: \(activeConnection.configuration.url)")

            if !AppSettings.shared.haveReceivedAppContext {
                AppMessageService.singleton.requestApplicationContext()
                errorDescription = NSLocalizedString("settings_not_received", comment: "")
                showAlert = true
                continue
            }

            AppSettings.shared.openHABRootUrl = activeConnection.configuration.url
            AppSettings.shared.openHABVersion = activeConnection.version

            // TODO: Check whether there is need to setup requestModifier for Kingfisher

            startPageHandling(sitemapName: AppSettings.shared.sitemapForWatch)
        }
    }

    func updateNetwork() async {
        guard let connection1 = AppSettings.shared.localConnectionConfig,
              let connection2 = AppSettings.shared.remoteConnectionConfig else {
            logger.info("No connections defined")
            return
        }
        NetworkTracker.shared.startTracking(connectionConfigurations: [connection1, connection2])
    }

    func startPageHandling(sitemapName: String, pageId: String = "") {
        pageHandlingTask?.cancel()

        pageHandlingTask = Task {
            do {
                isLoadingSitemap = true
                let service = try OpenAPIService(connectionConfiguration: NetworkTracker.shared.activeConnection?.configuration ?? ConnectionConfiguration.remoteDefault)

                let initialPage = try await service.pollDataForPage(sitemapname: sitemapName, pageId: pageId, longPolling: false)
                try Task.checkCancellation()

                await MainActor.run {
                    self.openHABSitemapPage = initialPage
                    self.widgets = initialPage?.widgets ?? []
                    openHABSitemapPage?.sendCommand = { [weak self] item, command in
                        Task { await self?.sendCommand(item, command: command) }
                    }
                    self.isLoadingSitemap = false
                }

                // Long polling loop with backoff
                var backoffAttempt = 0
                let maxBackoffDelay: UInt64 = 30_000_000_000 // 30 seconds

                while !Task.isCancelled {
                    do {
                        let page = try await service.pollDataForPage(sitemapname: sitemapName, pageId: pageId, longPolling: true)
                        try Task.checkCancellation()

                        await MainActor.run {
                            self.openHABSitemapPage = page
                            openHABSitemapPage?.sendCommand = { [weak self] item, command in
                                Task { await self?.sendCommand(item, command: command) }
                            }
                            self.widgets = page?.widgets ?? []
                        }

                        // Reset backoff after success
                        backoffAttempt = 0

                    } catch {
                        backoffAttempt += 1
                        let baseDelay = min(UInt64(pow(2.0, Double(backoffAttempt))) * 1_000_000_000, maxBackoffDelay)
                        let jitter = UInt64.random(in: 0 ..< (baseDelay / 2))
                        let totalDelay = baseDelay + jitter

                        logger.warning("Polling failed: \(error.localizedDescription). Retrying in \(Double(totalDelay) / 1_000_000_000.0) seconds.")

                        try await Task.sleep(nanoseconds: totalDelay)
                    }
                }
            } catch {
                await MainActor.run {
                    logger.error("Page handling failed with error \(error.localizedDescription)")
                    self.widgets = []
                    self.errorDescription = error.localizedDescription
                    self.showAlert = true
                    self.isLoadingSitemap = false
                }
            }
        }
    }

    func stopLongPolling() {
        pageHandlingTask?.cancel()
        pageHandlingTask = nil
        isPolling = false
        isLoadingSitemap = false
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
        guard AppSettings.shared.haveReceivedAppContext, !AppSettings.shared.openHABRootUrl.isEmpty else { return }

        showAlert = false
        startPageHandling(sitemapName: AppSettings.shared.sitemapForWatch)
    }
}
