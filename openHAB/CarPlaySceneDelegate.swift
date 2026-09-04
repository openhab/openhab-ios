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
import CommonUI
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
    // Tracks the buttons currently on screen, keyed by widgetId, so updateTemplate can mutate
    // existing CPGridButton instances in place (iOS 26+) instead of replacing the whole array —
    // CPGridTemplate.updateGridButtons(_:) resets CarPlay's focused button, so avoiding it when
    // only a button's state (not the widget set/order) changed keeps focus on the pressed button.
    private var gridButtonsByWidgetId: [String: CPGridButton] = [:]
    private var gridButtonOrder: [String] = []

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
        preferencesTask = Task { [weak self] in
            // currentHomePreferencesStream is backed by currentHomePreferencesPublisher but
            // delivered via AsyncStream continuation — avoids the dispatch_assert_queue crash
            // that the Combine AsyncPublisher bridge (.values) caused here previously.
            var lastSitemap = await Preferences.shared.currentHomePreferences.sitemapForCarPlay
            for await prefs in await Preferences.shared.currentHomePreferencesStream {
                guard !Task.isCancelled else { break }
                let newSitemap = prefs.sitemapForCarPlay
                guard newSitemap != lastSitemap else { continue }
                lastSitemap = newSitemap
                // Sitemap selection changed — full restart needed (different page/subscription).
                await MainActor.run { self?.startStreaming() }
            }
        }
    }

    @MainActor
    private func runStream() async {
        let prefs = await Preferences.shared.currentHomePreferences
        await NetworkTracker.shared.startTracking(connectionConfigurations: [
            prefs.localConnectionConfig,
            prefs.remoteConnectionConfig
        ])
        guard let connection = await NetworkTracker.shared.waitForActiveConnection() else {
            Logger.carPlay.warning("CarPlay: no active connection")
            return
        }
        let sitemapName = (await Preferences.shared.currentHomePreferences).sitemapForCarPlay
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
            gridButtonsByWidgetId.removeAll()
            gridButtonOrder = []
            interfaceController?.setRootTemplate(placeholderTemplate(), animated: false, completion: nil)
            return
        }

        let title = page.title.isEmpty ? "openHAB" : "openHAB – \(page.title)"
        let newOrder = widgets.map(\.widgetId)

        if #available(iOS 26.0, *),
           let existing = currentGridTemplate,
           newOrder == gridButtonOrder {
            // Same buttons, same order — update each in place so CarPlay doesn't reset focus.
            existing.updateTitle(title)
            for widget in widgets {
                guard let button = gridButtonsByWidgetId[widget.widgetId] else { continue }
                button.updateTitleVariants([widget.displayState.labelText])
                button.updateImage(sfSymbol(for: widget))
            }
            return
        }

        // Button set/order changed, or pre-iOS 26 — full rebuild (resets CarPlay's focus).
        let buttons = widgets.map { makeGridButton(for: $0, service: service) }
        gridButtonOrder = newOrder
        gridButtonsByWidgetId = Dictionary(zip(newOrder, buttons), uniquingKeysWith: { first, _ in first })

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
        // Determine the CarPlay grid button box and choose a comfortable symbol point size
        let box = carPlayGridButtonImageSize()
        let pointSize = min(box.width, box.height) * 0.8

        // Build the configured SF Symbol image (vector-backed), template rendering
        let symbol = openHABSFSymbol(for: widget.icon, isOn: widget.displayState.isOn)
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular, scale: .medium)
        let baseImage = UIImage(systemSymbol: symbol)
            .applyingSymbolConfiguration(config)?
            .withRenderingMode(.alwaysTemplate)
            ?? UIImage(systemSymbol: symbol).withRenderingMode(.alwaysTemplate)

        // Render into a square canvas using aspect-fit to avoid any stretching
        return renderSymbolImage(baseImage, pointSize: pointSize, boxSize: box)
    }

    /// Renders a symbol-configured UIImage into a square canvas sized for CarPlay grid buttons,
    /// preserving aspect ratio (aspect-fit)
    private func renderSymbolImage(_ image: UIImage, pointSize: CGFloat, boxSize: CGSize) -> UIImage {
        // Ensure a square canvas based on the smaller dimension of CarPlay's suggested size
        let side = min(boxSize.width, boxSize.height)
        let canvasSize = CGSize(width: side, height: side)

        let drawRect = CGRect(x: 0, y: 0, width: side, height: side)

        // Determine the size the image should be drawn at to preserve its aspect ratio inside drawRect
        let imgSize = image.size
        var target = drawRect
        if imgSize.width > 0, imgSize.height > 0 {
            let imgAspect = imgSize.width / imgSize.height
            let boxAspect = drawRect.width / drawRect.height
            if imgAspect > boxAspect {
                // Image is wider: fit width, adjust height
                let height = drawRect.width / imgAspect
                target = CGRect(x: drawRect.minX, y: drawRect.midY - height / 2, width: drawRect.width, height: height)
            } else {
                // Image is taller: fit height, adjust width
                let width = drawRect.height * imgAspect
                target = CGRect(x: drawRect.midX - width / 2, y: drawRect.minY, width: width, height: drawRect.height)
            }
        }

        // Render with correct scale
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let rendered = renderer.image { _ in
            // Fill nothing; keep transparent background so CarPlay can tint the template image
            image.draw(in: target, blendMode: .normal, alpha: 1.0)
        }
        return rendered.withRenderingMode(.alwaysTemplate)
    }

    private func isCarPlayCompatible(_ widget: OpenHABWidget) -> Bool {
        guard widget.type == .switchWidget, widget.item != nil else { return false }
        return widget.mappings.isEmpty ||
            (widget.mappings.count == 1 && widget.mappings[0].hasPressReleaseBehavior)
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
        return CPGridButton(titleVariants: [ds.labelText], image: image) { _ in
            Task {
                guard let name = widget.item?.name else { return }
                // Resolve press/release source: single mapping takes precedence over widget-level fields
                let pressCommand: String?
                let releaseCommand: String?
                if let mapping = widget.mappings.first, mapping.hasPressReleaseBehavior {
                    pressCommand = mapping.command.isEmpty ? nil : mapping.command
                    releaseCommand = mapping.releaseCommand
                } else {
                    pressCommand = widget.releaseOnly != true ? widget.command : nil
                    releaseCommand = widget.releaseCommand
                }
                if let pressCommand {
                    try? await service.sendItemCommand(itemname: name, command: pressCommand)
                    try? await Task.sleep(for: .milliseconds(500))
                }
                if let releaseCommand {
                    try? await service.sendItemCommand(itemname: name, command: releaseCommand)
                } else {
                    // Read displayState live (not the `ds` captured at button-creation time):
                    // with in-place button updates (iOS 26+) this closure can outlive many state
                    // changes, so a captured snapshot would freeze the on/off guess at whatever
                    // it was when the button was first built.
                    try? await service.sendItemCommand(itemname: name, command: widget.displayState.isOn ? "OFF" : "ON")
                }
            }
        }
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
