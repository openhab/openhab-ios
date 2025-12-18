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
import CommonUI
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
            .debounce(for: .seconds(2.0), scheduler: RunLoop.main)
            .sink { [weak self] newValue in
                guard !newValue.isEmpty else { return }
                Task { @MainActor in
                    guard let self else { return }

                    // Check if we have an active connection before starting
                    guard await NetworkTracker.shared.activeConnection != nil else { return }

                    // Only force restart if the sitemap name actually changed
                    let isDifferentSitemap = self.currentlyLoadingSitemap != newValue
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

            if !AppSettings.shared.haveReceivedAppContext {
                AppMessageService.singleton.requestApplicationContext()
                errorDescription = NSLocalizedString("settings_not_received", comment: "")
                showAlert = true
                continue
            }

            AppSettings.shared.openHABRootUrl = activeConnection.configuration.url
            AppSettings.shared.openHABVersion = activeConnection.version

            // If we have a sitemap but nothing is loading, start page handling
            let sitemapName = AppSettings.shared.sitemapForWatch
            if !sitemapName.isEmpty, currentlyLoadingSitemap == nil {
                startPageHandling(sitemapName: sitemapName, force: false)
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
        // Handle concurrent loads based on force parameter
        if let task = pageHandlingTask, !task.isCancelled {
            if currentlyLoadingSitemap == sitemapName {
                if force {
                    task.cancel()
                } else {
                    return
                }
            } else {
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
                        self.pageHandlingTask = nil
                        self.currentlyLoadingSitemap = nil
                    }
                }
            }

            do {
                isLoadingSitemap = true
                let activeNetworkConfig = await NetworkTracker.shared.activeConnection?.configuration
                let service = try OpenAPIService(connectionConfiguration: activeNetworkConfig ?? ConnectionConfiguration.remoteDefault)

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
