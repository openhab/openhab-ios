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

private let carPlayMaxItems = 8

final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var streamTask: Task<Void, Never>?
    private var preferencesTask: Task<Void, Never>?
    private let sitemapEventStream = SitemapEventStream()

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
        preferencesTask?.cancel()
        preferencesTask = nil
        Task { await sitemapEventStream.stop() }
        self.interfaceController = nil
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
                startStreaming()
            }
        }
    }

    @MainActor
    private func runStream() async {
        guard let connection = await NetworkTracker.shared.waitForActiveConnection() else {
            Logger.carPlay.warning("CarPlay: no active connection")
            return
        }
        let sitemapName = Preferences.shared.currentHomePreferences.sitemapForCarPlay
        guard !sitemapName.isEmpty else {
            Logger.carPlay.info("CarPlay: no sitemap configured")
            return
        }
        do {
            let service = try OpenAPIService(connectionConfiguration: connection.configuration)

            // Initial fetch to populate the template and learn the pageId
            guard let page = try await service.pollDataForPage(
                sitemapname: sitemapName, pageId: "", longPolling: false
            ) else { return }
            updateTemplate(page: page, service: service)

            // Prefer SSE; fall back to long-poll on older servers
            let serverProps = try? await service.getRoot()
            if serverProps?.hasSseSupport() == true {
                await runSSE(page: page, sitemapName: sitemapName, connection: connection, service: service)
            } else {
                await runLongPoll(sitemapName: sitemapName, pageId: page.pageId, service: service)
            }
        } catch {
            Logger.carPlay.error("CarPlay stream error: \(error)")
        }
    }

    @MainActor
    private func runSSE(page: OpenHABPage, sitemapName: String, connection: ConnectionInfo, service: OpenAPIService) async {
        await sitemapEventStream.startMonitoringNetworkIfNeeded(initialConnection: connection)
        let pageId = page.pageId.isEmpty ? sitemapName : page.pageId
        let stream = await sitemapEventStream.stream(sitemap: sitemapName, pageId: pageId)
        Logger.carPlay.info("CarPlay SSE starting for \(sitemapName)/\(pageId)")

        for await msg in stream {
            guard !Task.isCancelled else { break }
            switch msg {
            case .connected:
                Logger.carPlay.info("CarPlay SSE connected")
            case let .disconnected(error):
                if let error { Logger.carPlay.warning("CarPlay SSE disconnected: \(error)") }
            case let .event(message):
                handleSseMessage(message, page: page, service: service)
            }
        }
    }

    @MainActor
    private func handleSseMessage(_ message: SitemapEventMessage, page: OpenHABPage, service: OpenAPIService) {
        switch message {
        case .alive:
            break
        case .sitemapChanged:
            Logger.carPlay.info("CarPlay SSE: sitemap changed, reloading")
            startStreaming()
        case let .widget(event):
            switch page.apply(event: event) {
            case .applied:
                updateTemplate(page: page, service: service)
            case .requiresPageReload, .notFound:
                Logger.carPlay.info("CarPlay SSE: widget requires reload")
                startStreaming()
            case .unchanged:
                break
            }
        case let .unknown(raw):
            Logger.carPlay.debug("CarPlay SSE unknown: \(raw)")
        }
    }

    @MainActor
    private func runLongPoll(sitemapName: String, pageId: String, service: OpenAPIService) async {
        Logger.carPlay.info("CarPlay using long-poll for \(sitemapName)")
        do {
            for try await event in SitemapPageLoader.stream(sitemapName: sitemapName, pageId: pageId, service: service) {
                guard !Task.isCancelled else { break }
                if case let .longPoll(page, _) = event {
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
        let items = page.widgets
            .filter { $0.visibility && isCarPlayCompatible($0) }
            .prefix(carPlayMaxItems)
            .map { makeItem(for: $0, service: service) }

        let section = CPListSection(items: Array(items))
        let template = CPListTemplate(title: "openHAB", sections: [section])
        interfaceController?.setRootTemplate(template, animated: false, completion: nil)
    }

    private func isCarPlayCompatible(_ widget: OpenHABWidget) -> Bool {
        switch widget.type {
        case .switchWidget, .text, .button, .selection: true
        default: false
        }
    }

    private func makeItem(for widget: OpenHABWidget, service: OpenAPIService) -> CPListItem {
        let ds = widget.displayState

        switch widget.type {
        case .switchWidget where !ds.mappings.isEmpty:
            let item = CPListItem(text: ds.labelText, detailText: ds.selectedLabel ?? ds.labelValue)
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, done in
                self?.pushMappingList(title: ds.labelText, mappings: ds.mappings, widget: widget, service: service)
                done()
            }
            return item

        case .switchWidget:
            let item = CPListItem(text: ds.labelText, detailText: ds.isOn ? "ON" : "OFF")
            item.handler = { _, done in
                Task {
                    guard let name = widget.item?.name else { return }
                    try? await service.sendItemCommand(itemname: name, command: ds.isOn ? "OFF" : "ON")
                }
                done()
            }
            return item

        case .button:
            let item = CPListItem(text: ds.labelText, detailText: ds.labelValue)
            item.handler = { _, done in
                Task {
                    guard let name = widget.item?.name, let command = widget.command else { return }
                    try? await service.sendItemCommand(itemname: name, command: command)
                }
                done()
            }
            return item

        case .selection:
            let item = CPListItem(text: ds.labelText, detailText: ds.selectedLabel ?? ds.labelValue)
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, done in
                self?.pushMappingList(title: ds.labelText, mappings: ds.mappings, widget: widget, service: service)
                done()
            }
            return item

        default:
            return CPListItem(text: ds.labelText, detailText: ds.labelValue)
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

    private func placeholderTemplate() -> CPListTemplate {
        let item = CPListItem(
            text: String(localized: "carplay_not_configured"),
            detailText: String(localized: "carplay_not_configured_detail")
        )
        return CPListTemplate(title: "openHAB", sections: [CPListSection(items: [item])])
    }
}
