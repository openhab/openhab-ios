// Copyright (c) 2010-2026 Contributors to the openHAB project
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

    /// Initializes UserData for a linked page navigation
    init(linkedPage: OpenHABPage) {
        // Use the pageId directly from the linkedPage object
        let extractedPageId = linkedPage.pageId

        Logger.userData.info("Initializing UserData for linked page: '\(linkedPage.title)' with pageId: '\(extractedPageId)', link: '\(linkedPage.link)'")

        setupNotificationObservers()

        // Start loading the linked page
        Task { @MainActor in
            let sitemapName = AppSettings.shared.sitemapForWatch
            guard !sitemapName.isEmpty else {
                Logger.userData.error("Cannot load linked page: no sitemap configured")
                self.errorDescription = "No sitemap configured"
                self.showAlert = true
                return
            }
            Logger.userData.info("Starting page handling for sitemap: \(sitemapName), pageId: \(extractedPageId)")
            self.startPageHandling(sitemapName: sitemapName, pageId: extractedPageId, force: true)
        }
    }

    init() {
        setupNotificationObservers()

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
                Logger.userData.debug("Sitemap observer fired: \(newValue)")
                Task { @MainActor in
                    guard let self else { return }

                    // Only force restart if the sitemap name actually changed
                    let isDifferentSitemap = self.currentlyLoadingSitemap != newValue
                    Logger.userData.debug("Sitemap change detected - current: \(self.currentlyLoadingSitemap ?? "nil"), new: \(newValue), force: \(isDifferentSitemap)")

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

    /// Sets up notification observers for certificate validation and changes
    private func setupNotificationObservers() {
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
    }

    /// Observes network connection changes and updates state
    private func observeNetworkChanges() async {
        let activeConnectionStream = await NetworkTracker.shared.activeConnectionStream()
        for await activeConnection in activeConnectionStream {
            guard let activeConnection else {
                continue
            }

            Logger.userData.debug("Network connection became available: \(activeConnection.configuration.url)")

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
                        Logger.userData.debug("Page handling task already running for correct sitemap: \(sitemapName)")
                    } else {
                        // Running task is for different sitemap, force reload
                        Logger.userData.debug("Page handling task for wrong sitemap, forcing reload: \(sitemapName)")
                        startPageHandling(sitemapName: sitemapName, force: true)
                    }
                } else {
                    // No task running or task is cancelled - start a new one
                    Logger.userData.debug("Starting page handling for sitemap: \(sitemapName) after network became available")
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
        Logger.userData.debug("startPageHandling called - sitemap: \(sitemapName), pageId: \(pageId), force: \(force)")

        // Handle concurrent loads based on force parameter
        if let task = pageHandlingTask, !task.isCancelled {
            if currentlyLoadingSitemap == sitemapName {
                if force {
                    Logger.userData.debug("Cancelling existing task for same sitemap (force=true)")
                    task.cancel()
                } else {
                    Logger.userData.debug("Same sitemap already loading and force=false, skipping")
                    return
                }
            } else {
                Logger.userData.debug("Cancelling existing task for different sitemap")
                task.cancel()
            }
        }
        currentlyLoadingSitemap = sitemapName

        pageHandlingTask = Task {
            let taskSitemapName = sitemapName // Capture the sitemap name for this specific task
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

            do {
                isLoadingSitemap = true

                // Wait for NetworkTracker to establish a connection (no fallback hacks needed!)
                guard let connectionInfo = await NetworkTracker.shared.waitForActiveConnection() else {
                    Logger.userData.error("No active connection available after timeout")
                    await MainActor.run {
                        self.errorDescription = NSLocalizedString("settings_not_received", comment: "")
                        self.showAlert = true
                        self.isLoadingSitemap = false
                    }
                    return
                }

                Logger.userData.debug("Using connection: \(connectionInfo.configuration.url)")
                let service = try OpenAPIService(connectionConfiguration: connectionInfo.configuration, serviceConfiguration: .longTerm)

                let initialPage = try await service.pollDataForPage(sitemapname: sitemapName, pageId: pageId, longPolling: false)
                try Task.checkCancellation()

                await MainActor.run {
                    // Set command handler BEFORE assigning to @Published property to prevent race condition
                    initialPage?.sendCommand = { [weak self] item, command in
                        Task { await self?.sendCommand(item, command: command) }
                    }
                    self.openHABSitemapPage = initialPage
                    let newWidgets = initialPage?.widgets ?? []
                    self.updateWidgets(with: newWidgets)
                    if !newWidgets.isEmpty {
                        self.cachedWidgets = newWidgets
                    }
                    self.isLoadingSitemap = false
                }

                // Long polling loop with backoff
                var backoffAttempt = 0
                let maxBackoffDelay: UInt64 = 30_000_000_000 // 30 seconds

                Logger.userData.debug("Starting long polling loop for sitemap: \(taskSitemapName)")
                while !Task.isCancelled {
                    do {
                        let page = try await service.pollDataForPage(sitemapname: sitemapName, pageId: pageId, longPolling: true)
                        try Task.checkCancellation()

                        await MainActor.run {
                            // Set command handler BEFORE assigning to @Published property to prevent race condition
                            if let page {
                                page.sendCommand = { [weak self] item, command in
                                    Task { await self?.sendCommand(item, command: command) }
                                }
                            }
                            self.openHABSitemapPage = page
                            let newWidgets = page?.widgets ?? []
                            self.updateWidgets(with: newWidgets)
                            if !newWidgets.isEmpty {
                                self.cachedWidgets = newWidgets
                            }
                        }

                        // Reset backoff after success
                        backoffAttempt = 0

                    } catch is CancellationError {
                        Logger.userData.debug("Long polling cancelled for sitemap: \(taskSitemapName)")
                        throw CancellationError()
                    } catch {
                        backoffAttempt += 1
                        let baseDelay = min(UInt64(pow(2.0, Double(backoffAttempt))) * 1_000_000_000, maxBackoffDelay)
                        let jitter = UInt64.random(in: 0 ..< (baseDelay / 2))
                        let totalDelay = baseDelay + jitter

                        Logger.userData.warning("Polling failed: \(error.localizedDescription) (\(type(of: error))). Retrying in \(Double(totalDelay) / 1_000_000_000.0) seconds.")

                        try await Task.sleep(nanoseconds: totalDelay)
                    }
                }
            } catch {
                await MainActor.run {
                    Logger.userData.error("Page handling failed for sitemap '\(taskSitemapName)': \(error.localizedDescription)")
                    Logger.userData.error("Error type: \(String(describing: type(of: error)))")

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
                // Note: NetworkTracker will automatically handle failover to remote if local fails
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

    /// Updates existing widget instances instead of replacing them to preserve @ObservedObject references
    private func updateWidgets(with newWidgets: [OpenHABWidget]) {
        let existingWidgetsMap = Dictionary(uniqueKeysWithValues: widgets.map { ($0.widgetId, $0) })

        // Check if the widget list structure changed (count, order, or IDs)
        let structureChanged = widgets.count != newWidgets.count
            || !zip(widgets, newWidgets).allSatisfy({ $0.widgetId == $1.widgetId })

        for newWidget in newWidgets {
            if let existingWidget = existingWidgetsMap[newWidget.widgetId] {
                // Update existing widget's properties in place — this triggers
                // per-row re-renders via @ObservedObject without rebuilding the list
                existingWidget.label = newWidget.label
                existingWidget.type = newWidget.type
                existingWidget.icon = newWidget.icon
                existingWidget.state = newWidget.state
                existingWidget.item = newWidget.item
                existingWidget.iconColor = newWidget.iconColor
                existingWidget.labelcolor = newWidget.labelcolor
                existingWidget.valuecolor = newWidget.valuecolor
                existingWidget.url = newWidget.url
                existingWidget.period = newWidget.period
                existingWidget.service = newWidget.service
                existingWidget.legend = newWidget.legend
                existingWidget.refresh = newWidget.refresh
                existingWidget.height = newWidget.height
                existingWidget.forceAsItem = newWidget.forceAsItem
                existingWidget.mappings = newWidget.mappings
                existingWidget.widgets = newWidget.widgets
            }
        }

        // Only reassign the @Published array when the list structure actually
        // changed (widgets added, removed, or reordered). This avoids a full
        // ScrollView rebuild that resets the scroll position.
        if structureChanged {
            var updatedWidgets: [OpenHABWidget] = []
            for newWidget in newWidgets {
                updatedWidgets.append(existingWidgetsMap[newWidget.widgetId] ?? newWidget)
            }
            widgets = updatedWidgets
        }
    }
}
