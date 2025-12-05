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
        // Note: We don't use .dropFirst() here because we need to catch the initial value
        // when the app context is first received from the iOS app on real devices
        AppSettings.shared.$sitemapForWatch
            .removeDuplicates()
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .sink { [weak self] newValue in
                guard !newValue.isEmpty else {
                    Logger.userData.debug("Sitemap observer: empty sitemap, ignoring")
                    return
                }
                Logger.userData.info("Sitemap observer fired: \(newValue)")
                Task { @MainActor in
                    guard let self else { return }

                    // Only force restart if the sitemap name actually changed
                    let isDifferentSitemap = self.currentlyLoadingSitemap != newValue
                    Logger.userData.info("Sitemap change detected - current: \(self.currentlyLoadingSitemap ?? "nil"), new: \(newValue), force: \(isDifferentSitemap)")

                    // Note: We don't check for active connection here because NetworkTracker
                    // can report false negatives (especially during long-polling on real devices).
                    // The observeNetworkChanges() function will handle retrying when network becomes available.
                    self.startPageHandling(sitemapName: newValue, force: isDifferentSitemap)
                }
            }
            .store(in: &cancellables)

        // Also observe connection config changes - update network when server changes
        AppSettings.shared.$localConnectionConfig
            .combineLatest(AppSettings.shared.$remoteConnectionConfig)
            .dropFirst() // Skip initial values
            .removeDuplicates { lhs, rhs in
                // Only trigger if actual connection URLs changed
                lhs.0?.url == rhs.0?.url && lhs.1?.url == rhs.1?.url
            }
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _, _ in
                Task { @MainActor in
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
        let activeConnectionStream = await NetworkTracker.shared.activeConnectionStream()
        for await activeConnection in activeConnectionStream {
            guard let activeConnection else {
                continue
            }

            Logger.userData.info("Network connection became available: \(activeConnection.configuration.url)")

            if !AppSettings.shared.haveReceivedAppContext {
                AppMessageService.singleton.requestApplicationContext()
                errorDescription = NSLocalizedString("settings_not_received", comment: "")
                showAlert = true
                continue
            }

            AppSettings.shared.openHABRootUrl = activeConnection.configuration.url
            AppSettings.shared.openHABVersion = activeConnection.version

            // Start page handling when network becomes available
            let sitemapName = AppSettings.shared.sitemapForWatch
            if !sitemapName.isEmpty {
                // Check if there's already a running task
                if let task = pageHandlingTask, !task.isCancelled {
                    // Task is running, check if it's for the right sitemap
                    if currentlyLoadingSitemap == sitemapName {
                        Logger.userData.info("Page handling task already running for correct sitemap: \(sitemapName)")
                    } else {
                        // Running task is for different sitemap, force reload
                        Logger.userData.info("Page handling task for wrong sitemap, forcing reload: \(sitemapName)")
                        startPageHandling(sitemapName: sitemapName, force: true)
                    }
                } else {
                    // No task running or task is cancelled - start a new one
                    Logger.userData.info("Starting page handling for sitemap: \(sitemapName) after network became available")
                    startPageHandling(sitemapName: sitemapName, force: false)
                }
            }
        }
    }

    func updateNetwork() async {
        guard let connection1 = AppSettings.shared.localConnectionConfig,
              let connection2 = AppSettings.shared.remoteConnectionConfig else {
            Logger.userData.warning("No connections defined")
            return
        }
        await NetworkTracker.shared.startTracking(connectionConfigurations: [connection1, connection2])
    }

    func startPageHandling(sitemapName: String, pageId: String = "", force: Bool = false) {
        Logger.userData.info("startPageHandling called - sitemap: \(sitemapName), pageId: \(pageId), force: \(force)")

        // Handle concurrent loads based on force parameter
        if let task = pageHandlingTask, !task.isCancelled {
            if currentlyLoadingSitemap == sitemapName {
                if force {
                    Logger.userData.info("Cancelling existing task for same sitemap (force=true)")
                    task.cancel()
                } else {
                    Logger.userData.info("Same sitemap already loading and force=false, skipping")
                    return
                }
            } else {
                Logger.userData.info("Cancelling existing task for different sitemap")
                task.cancel()
            }
        }
        currentlyLoadingSitemap = sitemapName

        pageHandlingTask = Task {
            let taskSitemapName = sitemapName  // Capture the sitemap name for this specific task
            defer {
                // Only clear references if this task is still the current one
                Task { @MainActor in
                    if self.currentlyLoadingSitemap == taskSitemapName {
                        Logger.userData.debug("Clearing page handling task for: \(taskSitemapName)")
                        self.pageHandlingTask = nil
                        self.currentlyLoadingSitemap = nil
                    }
                }
            }

            // Get connection configuration - prefer active, fallback to stored local config
            var connectionConfig = await NetworkTracker.shared.activeConnection?.configuration
            if connectionConfig == nil {
                // NetworkTracker can give false negatives on real devices, use stored config
                connectionConfig = AppSettings.shared.localConnectionConfig ?? AppSettings.shared.remoteConnectionConfig
                Logger.userData.warning("NetworkTracker has no active connection, using stored config: \(connectionConfig?.url ?? "none")")
            }

            guard let config = connectionConfig else {
                Logger.userData.error("No connection configuration available, cannot load sitemap")
                await MainActor.run {
                    self.errorDescription = "No connection configuration available"
                    self.showAlert = true
                    self.isLoadingSitemap = false
                }
                return
            }

            do {
                isLoadingSitemap = true
                let service = try OpenAPIService(connectionConfiguration: config)

                let initialPage = try await service.pollDataForPage(sitemapname: sitemapName, pageId: pageId, longPolling: false)
                try Task.checkCancellation()

                await MainActor.run {
                    // Set command handler BEFORE assigning to @Published property to prevent race condition
                    initialPage?.sendCommand = { [weak self] item, command in
                        Task { await self?.sendCommand(item, command: command) }
                    }
                    self.openHABSitemapPage = initialPage
                    let newWidgets = initialPage?.widgets ?? []
                    self.widgets = newWidgets
                    if !newWidgets.isEmpty {
                        self.cachedWidgets = newWidgets
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
                            // Set command handler BEFORE assigning to @Published property to prevent race condition
                            page?.sendCommand = { [weak self] item, command in
                                Task { await self?.sendCommand(item, command: command) }
                            }
                            self.openHABSitemapPage = page
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
                // Check if this was a network error and we should try remote fallback
                let shouldTryRemote = (error as? URLError)?.code == .cannotConnectToHost ||
                                     (error as? URLError)?.code == .timedOut ||
                                     (error as? URLError)?.code == .networkConnectionLost

                await MainActor.run {
                    Logger.userData.error("Page handling failed for sitemap '\(taskSitemapName)': \(error.localizedDescription)")
                    Logger.userData.error("Error type: \(String(describing: type(of: error)))")

                    // If local connection failed and remote is available, try remote as fallback
                    if shouldTryRemote,
                       let remoteConfig = AppSettings.shared.remoteConnectionConfig,
                       remoteConfig.url != connectionConfig?.url {
                        Logger.userData.info("Local connection failed, retrying with remote: \(remoteConfig.url)")
                        // Retry with remote connection
                        Task {
                            await MainActor.run {
                                self.startPageHandling(sitemapName: taskSitemapName, force: true)
                            }
                        }
                        return
                    }

                    // Use cached widgets if available instead of clearing completely
                    if self.cachedWidgets.isEmpty {
                        Logger.userData.warning("No cached widgets available, showing empty state")
                        self.widgets = []
                    } else {
                        self.widgets = self.cachedWidgets
                        Logger.userData.info("Using \(self.cachedWidgets.count) cached widgets during connection failure")
                    }
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
            Logger.userData.error("Failed to send command '\(command)' to '\(item.name)': \(error.localizedDescription)")
        }
    }

    func refreshUrl() async {
        guard AppSettings.shared.haveReceivedAppContext, !AppSettings.shared.openHABRootUrl.isEmpty else { return }

        showAlert = false
        startPageHandling(sitemapName: AppSettings.shared.sitemapForWatch)
    }
}
