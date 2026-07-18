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

import CarPlay
import OpenHABCore
import os.log
import SFSafeSymbols

private var carPlayMaxItems: Int {
    Int(CPGridTemplateMaximumItems)
}

final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var streamTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var preferencesTask: Task<Void, Never>?
    private let sitemapEventStream = SitemapEventStream()
    private var currentGridTemplate: CPGridTemplate?
    // Retained across SSE restarts so page refreshes don't need a full stream teardown.
    private var currentPage: OpenHABPage?
    private var currentService: OpenAPIService?

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        interfaceController.setRootTemplate(placeholderTemplate(), animated: false, completion: nil)
        startStreaming()
        startObservingPreferences()
        Logger.carPlay.info("CarPlay scene connected")
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        streamTask?.cancel()
        streamTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        preferencesTask?.cancel()
        preferencesTask = nil
        Task { await sitemapEventStream.stop() }
        self.interfaceController = nil
        currentGridTemplate = nil
        currentPage = nil
        currentService = nil
        Logger.carPlay.info("CarPlay scene disconnected")
    }

    // MARK: - Streaming

    private func startStreaming() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in await self?.runStream() }
    }

    private func startObservingPreferences() {
        preferencesTask?.cancel()
        preferencesTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var lastSitemap = Preferences.shared.currentHomePreferences.sitemapForCarPlay
            for await _ in NotificationCenter.default.notifications(named: UserDefaults.didChangeNotification) {
                guard !Task.isCancelled else { break }
                let newSitemap = Preferences.shared.currentHomePreferences.sitemapForCarPlay
                guard newSitemap != lastSitemap else { continue }
                lastSitemap = newSitemap
                // Sitemap selection changed — full restart needed (different page/subscription).
                startStreaming()
            }
        }
    }

    @MainActor
    private func runStream() async {
        let prefs = Preferences.shared.currentHomePreferences
        await NetworkTracker.shared.startTracking(connectionConfigurations: [
            prefs.localConnectionConfig,
            prefs.remoteConnectionConfig
        ])
        guard let connection = await NetworkTracker.shared.waitForActiveConnection() else {
            Logger.carPlay.warning("CarPlay: no active connection")
            return
        }
        let sitemapName = Preferences.shared.currentHomePreferences.sitemapForCarPlay
        guard !sitemapName.isEmpty else {
            Logger.carPlay.info("CarPlay: no sitemap configured")
            interfaceController?.setRootTemplate(
                placeholderTemplate(message: String(localized: "carplay_not_configured_detail")),
                animated: false, completion: nil
            )
            return
        }
        do {
            let service = try OpenAPIService(connectionConfiguration: connection.configuration)
            currentService = service

            guard let page = try await service.pollDataForPage(
                sitemapname: sitemapName, pageId: "", longPolling: false
            ) else { return }
            currentPage = page
            updateTemplate(page: page, service: service)

            let serverProps = try? await service.getRoot()
            if serverProps?.hasSseSupport() == true {
                await runSSE(sitemapName: sitemapName, connection: connection)
            } else {
                await runLongPoll(sitemapName: sitemapName, pageId: page.pageId, service: service)
            }
        } catch {
            Logger.carPlay.error("CarPlay stream error: \(error)")
        }
    }

    @MainActor
    private func runSSE(sitemapName: String, connection: ConnectionInfo) async {
        await sitemapEventStream.startMonitoringNetworkIfNeeded(initialConnection: connection)
        let pageId = currentPage.map { $0.pageId.isEmpty ? sitemapName : $0.pageId } ?? sitemapName
        let stream = await sitemapEventStream.stream(sitemap: sitemapName, pageId: pageId)
        Logger.carPlay.info("CarPlay SSE starting for \(sitemapName)/\(pageId)")

        // Refresh on reconnect so structural changes missed during a disconnect are caught.
        var needsRefreshOnReconnect = false

        for await msg in stream {
            guard !Task.isCancelled else { break }
            switch msg {
            case .connected:
                Logger.carPlay.info("CarPlay SSE connected")
                if needsRefreshOnReconnect {
                    needsRefreshOnReconnect = false
                    schedulePageRefresh(sitemapName: sitemapName)
                }
            case let .disconnected(error):
                needsRefreshOnReconnect = true
                if let error { Logger.carPlay.warning("CarPlay SSE disconnected: \(error)") }
            case let .event(message):
                handleSseMessage(message, sitemapName: sitemapName)
            }
        }
    }

    @MainActor
    private func handleSseMessage(_ message: SitemapEventMessage, sitemapName: String) {
        switch message {
        case .alive:
            break
        case .sitemapChanged:
            Logger.carPlay.info("CarPlay SSE: sitemap changed, refreshing page")
            // Refresh page content only — do not restart the SSE stream.
            schedulePageRefresh(sitemapName: sitemapName)
        case let .widget(event):
            guard let page = currentPage, let service = currentService else { return }
            switch page.apply(event: event) {
            case .applied:
                updateTemplate(page: page, service: service)
            case .requiresPageReload, .notFound:
                Logger.carPlay.info("CarPlay SSE: widget \(event.widgetId ?? "") requires reload")
                schedulePageRefresh(sitemapName: sitemapName)
            case .unchanged:
                break
            }
        case let .unknown(raw):
            Logger.carPlay.debug("CarPlay SSE unknown: \(raw)")
        }
    }

    /// Refreshes `currentPage` from the server and updates the template without restarting the SSE stream.
    /// Cancels any in-flight refresh so rapid events coalesce into a single fetch.
    private func schedulePageRefresh(sitemapName: String) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self, !Task.isCancelled else { return }
            await refreshPage(sitemapName: sitemapName)
        }
    }

    @MainActor
    private func refreshPage(sitemapName: String) async {
        guard let service = currentService else { return }
        do {
            guard let page = try await service.pollDataForPage(
                sitemapname: sitemapName, pageId: "", longPolling: false
            ) else { return }
            currentPage = page
            updateTemplate(page: page, service: service)
        } catch {
            Logger.carPlay.error("CarPlay page refresh error: \(error)")
        }
    }

    @MainActor
    private func runLongPoll(sitemapName: String, pageId: String, service: OpenAPIService) async {
        Logger.carPlay.info("CarPlay using long-poll for \(sitemapName)")
        do {
            for try await event in SitemapPageLoader.stream(sitemapName: sitemapName, pageId: pageId, service: service) {
                guard !Task.isCancelled else { break }
                if case let .longPoll(page, _) = event {
                    currentPage = page
                    updateTemplate(page: page, service: service)
                }
            }
        } catch {
            Logger.carPlay.error("CarPlay long-poll error: \(error)")
        }
    }

    // MARK: - Template building

    @MainActor
    private func updateTemplate(page: OpenHABPage, service: OpenAPIService) {
        let widgets = Array(
            page.widgets
                .filter { $0.visibility && isCarPlayCompatible($0) }
                .prefix(carPlayMaxItems)
        )

        guard !widgets.isEmpty else {
            currentGridTemplate = nil
            interfaceController?.setRootTemplate(placeholderTemplate(), animated: false, completion: nil)
            return
        }

        let title = page.title.isEmpty ? "openHAB" : "openHAB – \(page.title)"
        let buttons = widgets.map { makeGridButton(for: $0, service: service) }

        if let existing = currentGridTemplate {
            existing.updateTitle(title)
            existing.updateGridButtons(buttons)
        } else {
            let template = CPGridTemplate(title: title, gridButtons: buttons)
            currentGridTemplate = template
            interfaceController?.setRootTemplate(template, animated: false, completion: nil)
        }
    }

    private func sfSymbol(for widget: OpenHABWidget) -> UIImage {
        let targetSize = carPlayGridButtonImageSize()
        let pointSize = min(targetSize.width, targetSize.height)
        let isOn = widget.displayState.isOn

        let symbolName: SFSymbol = switch widget.icon.lowercased() {
        case "power", "poweroutlet", "poweroutlet_eu":
            isOn ? .powerCircleFill : .powerCircle
        case "lamp", "light", "lightbulb":
            isOn ? .lightbulbFill : .lightbulb
        default:
            isOn ? .circleFill : .circle
        }

        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)

        return UIImage(systemSymbol: symbolName)
            .applyingSymbolConfiguration(config)?
            .withRenderingMode(.alwaysTemplate)
            ?? UIImage(systemSymbol: symbolName).withRenderingMode(.alwaysTemplate)
    }

    private func isCarPlayCompatible(_ widget: OpenHABWidget) -> Bool {
        switch widget.type {
        case .switchWidget, .button, .selection: true
        default: false
        }
    }

    private func carPlayGridButtonImageSize() -> CGSize {
        if #available(iOS 26.0, *) {
            return CPGridTemplate.maximumGridButtonImageSize
        }

        // Conservative fallback for older CarPlay systems.
        return CGSize(width: 80, height: 80)
    }

    private func makeGridButton(for widget: OpenHABWidget, service: OpenAPIService) -> CPGridButton {
        let ds = widget.displayState
        let image = sfSymbol(for: widget)
        return CPGridButton(titleVariants: [ds.labelText], image: image) { [weak self] _ in
            guard let self else { return }
            switch widget.type {
            case .switchWidget where !ds.mappings.isEmpty, .selection:
                pushMappingList(title: ds.labelText, mappings: ds.mappings, widget: widget, service: service)
            case .switchWidget:
                Task {
                    guard let name = widget.item?.name else { return }
                    try? await service.sendItemCommand(itemname: name, command: ds.isOn ? "OFF" : "ON")
                }
            case .button:
                Task {
                    guard let name = widget.item?.name, let command = widget.command else { return }
                    try? await service.sendItemCommand(itemname: name, command: command)
                }
            default:
                break
            }
        }
    }

    private func pushMappingList(title: String,
                                 mappings: [OpenHABWidgetMapping],
                                 widget: OpenHABWidget,
                                 service: OpenAPIService) {
        let items = mappings.map { mapping -> CPListItem in
            let item = CPListItem(text: mapping.label, detailText: nil)
            item.handler = { [weak self] _, done in
                Task {
                    guard let name = widget.item?.name else { return }
                    try? await service.sendItemCommand(itemname: name, command: mapping.command)
                }
                self?.interfaceController?.popTemplate(animated: true, completion: nil)
                done()
            }
            return item
        }
        let template = CPListTemplate(title: title, sections: [CPListSection(items: items)])
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    private func placeholderButtonImage() -> UIImage {
        UIImage(named: "openHABIcon")?
            .withRenderingMode(.alwaysTemplate)
            .withTintColor(.secondaryLabel, renderingMode: .alwaysOriginal)
            ?? UIImage()
    }

    private func placeholderTemplate(message: String? = nil) -> CPTemplate {
        guard let message else {
            let button = CPGridButton(
                titleVariants: [String(localized: "carplay_not_configured")],
                image: placeholderButtonImage()
            ) { _ in }
            return CPGridTemplate(title: "openHAB", gridButtons: [button])
        }
        let item = CPInformationItem(title: nil, detail: message)
        return CPInformationTemplate(title: "openHAB", layout: .leading, items: [item], actions: [])
    }
}
