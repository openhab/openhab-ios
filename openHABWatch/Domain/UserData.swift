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

    // Cache last successful widgets to prevent empty state during reconnections
    private var cachedWidgets: [OpenHABWidget] = []
    private var currentlyLoadingSitemap: String?

    private var pageHandlingTask: Task<Void, Never>?
    @Published var isPolling = false

    @Published var openHABSitemapPage: OpenHABPage?
    var currentClientDelegate: HTTPClientDelegate?

    private var cancellables = Set<AnyCancellable>()

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
            Logger.userData.error("Should not throw \(error.localizedDescription)")
        }
    }

    init() {
        NotificationCenter.default.addObserver(
            forName: .evaluateServerTrust,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let summary = notification.userInfo?["summary"] as? String,
                  let domain = notification.userInfo?["domain"] as? String,
                  let delegate = notification.object as? HTTPClientDelegate else { return }
            DispatchQueue.main.async {
                self.certificateErrorDescription = String(format: NSLocalizedString("ssl_certificate_invalid", comment: ""), summary, domain)
                self.currentClientDelegate = delegate
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
                  let delegate = notification.object as? HTTPClientDelegate else { return }
            DispatchQueue.main.async {
                self.certificateErrorDescription = String(format: NSLocalizedString("ssl_certificate_no_match", comment: ""), summary, domain)
                self.currentClientDelegate = delegate
                self.showCertificateAlert = true
            }
        }

        NotificationCenter.default.addObserver(
            forName: .acceptedServerCertificatesChanged,
            object: nil,
            queue: nil
        ) { _ in
            Task { @MainActor in
                await NetworkTracker.shared.restartTracking()
            }
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

        // Observe sitemap changes - reload the sitemap when it changes
        AppSettings.shared.$sitemapForWatch
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] newValue in
                guard !newValue.isEmpty else { return }
                Task {
                    self?.startPageHandling(sitemapName: newValue, force: true)
                }
            }
            .store(in: &cancellables)

        // Also observe connection config changes - update network when server changes
        AppSettings.shared.$localConnectionConfig
            .combineLatest(AppSettings.shared.$remoteConnectionConfig)
            .dropFirst() // Skip initial values
            .sink { [weak self] _, _ in
                Logger.userData.info("Connection config changed, updating network")
                Task {
                    await self?.updateNetwork()
                }
            }
            .store(in: &cancellables)

        Task {
            await observeNetworkChanges()
        }
    }

    /// Observes network connection changes and updates state
    private func observeNetworkChanges() async {
        Logger.userData.info("👀 Starting to observe network changes")
        let activeConnectionStream = await NetworkTracker.shared.activeConnectionStream()
        for await activeConnection in activeConnectionStream {
            guard let activeConnection else {
                continue
            }

            Logger.userData.info("Active connection established: \(activeConnection.configuration.url)")

            if !AppSettings.shared.haveReceivedAppContext {
                Logger.userData.info("📥 Requesting app context from iOS")
                AppMessageService.singleton.requestApplicationContext()
                errorDescription = NSLocalizedString("settings_not_received", comment: "")
                showAlert = true
                continue
            }

            AppSettings.shared.openHABRootUrl = activeConnection.configuration.url
            AppSettings.shared.openHABVersion = activeConnection.version

            // TODO: Check whether there is need to setup requestModifier for Kingfisher

            startPageHandling(sitemapName: AppSettings.shared.sitemapForWatch, force: true)
        }
    }

    func updateNetwork() async {
        Logger.userData.info("🔧 updateNetwork called")
        guard let connection1 = AppSettings.shared.localConnectionConfig,
              let connection2 = AppSettings.shared.remoteConnectionConfig else {
            Logger.userData.info("❌ No connections defined")
            return
        }
        Logger.userData.info("🔌 Starting network tracking with local: \(connection1.url), remote: \(connection2.url)")
        await NetworkTracker.shared.startTracking(connectionConfigurations: [connection1, connection2])
        Logger.userData.info("✅ Network tracking started")
    }

    func startPageHandling(sitemapName: String, pageId: String = "", force: Bool = false) {
        // Handle concurrent loads based on force parameter
        if currentlyLoadingSitemap == sitemapName, pageHandlingTask != nil, !(pageHandlingTask?.isCancelled ?? true) {
            if force {
                pageHandlingTask?.cancel()
            } else {
                return
            }
        } else if currentlyLoadingSitemap != sitemapName, pageHandlingTask != nil, !(pageHandlingTask?.isCancelled ?? true) {
            // Switching to a different sitemap
            pageHandlingTask?.cancel()
        }
        currentlyLoadingSitemap = sitemapName

        pageHandlingTask = Task {
            do {
                isLoadingSitemap = true
                Logger.userData.info("🔄 Loading sitemap: \(sitemapName)")
                let activeNetworkConfig = await NetworkTracker.shared.activeConnection?.configuration
                Logger.userData.info("🌐 Active connection: \(activeNetworkConfig?.url ?? "none")")
                let service = try OpenAPIService(connectionConfiguration: activeNetworkConfig ?? ConnectionConfiguration.remoteDefault)

                let initialPage = try await service.pollDataForPage(sitemapname: sitemapName, pageId: pageId, longPolling: false)
                try Task.checkCancellation()

                await MainActor.run {
                    Logger.userData.info("✅ Loaded \(initialPage?.widgets.count ?? 0) widgets for sitemap: \(sitemapName)")
                    self.openHABSitemapPage = initialPage
                    // Set command handler BEFORE updating widgets to prevent race condition
                    openHABSitemapPage?.sendCommand = { [weak self] item, command in
                        Task { await self?.sendCommand(item, command: command) }
                    }
                    let newWidgets = initialPage?.widgets ?? []
                    self.widgets = newWidgets
                    if !newWidgets.isEmpty {
                        self.cachedWidgets = newWidgets
                    }
                    self.isLoadingSitemap = false
                    Logger.userData.info("🎨 UI should now update with \(newWidgets.count) widgets")
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
                            // Set command handler BEFORE updating widgets to prevent race condition
                            openHABSitemapPage?.sendCommand = { [weak self] item, command in
                                Task { await self?.sendCommand(item, command: command) }
                            }
                            let newWidgets = page?.widgets ?? []
                            self.widgets = newWidgets
                            if !newWidgets.isEmpty {
                                self.cachedWidgets = newWidgets
                            }
                        }

                        // Reset backoff after success
                        backoffAttempt = 0

                    } catch {
                        backoffAttempt += 1
                        let baseDelay = min(UInt64(pow(2.0, Double(backoffAttempt))) * 1_000_000_000, maxBackoffDelay)
                        let jitter = UInt64.random(in: 0 ..< (baseDelay / 2))
                        let totalDelay = baseDelay + jitter

                        Logger.userData.warning("Polling failed: \(error.localizedDescription). Retrying in \(Double(totalDelay) / 1_000_000_000.0) seconds.")

                        try await Task.sleep(nanoseconds: totalDelay)
                    }
                }
            } catch {
                await MainActor.run {
                    Logger.userData.error("Page handling failed with error \(error.localizedDescription)")
                    // Use cached widgets if available instead of clearing completely
                    if self.cachedWidgets.isEmpty {
                        self.widgets = []
                    } else {
                        self.widgets = self.cachedWidgets
                        Logger.userData.info("Using cached widgets during connection failure")
                    }
                    self.errorDescription = error.localizedDescription
                    self.showAlert = true
                    self.isLoadingSitemap = false
                    // Clear loading state only after error handling is complete
                    self.currentlyLoadingSitemap = nil
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
            Logger.userData.info("Could not send command \(command) to \(item.name)")
        }
    }

    func refreshUrl() async {
        guard AppSettings.shared.haveReceivedAppContext, !AppSettings.shared.openHABRootUrl.isEmpty else { return }

        showAlert = false
        startPageHandling(sitemapName: AppSettings.shared.sitemapForWatch)
    }
}
