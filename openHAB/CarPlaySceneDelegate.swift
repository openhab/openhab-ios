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
        self.interfaceController = nil
        Logger.carPlay.info("CarPlay scene disconnected")
    }

    // MARK: - Streaming

    private func startStreaming() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            await self?.runStream()
        }
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
            for try await event in SitemapPageLoader.stream(sitemapName: sitemapName, service: service) {
                guard !Task.isCancelled else { break }
                let page: OpenHABPage? = switch event {
                case let .initialFetch(page): page
                case let .longPoll(page, _): page
                }
                if let page { updateTemplate(page: page, service: service) }
            }
        } catch {
            Logger.carPlay.error("CarPlay stream error: \(error)")
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
