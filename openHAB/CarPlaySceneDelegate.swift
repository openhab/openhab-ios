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
import Kingfisher
import OpenHABCore
import os.log
import SFSafeSymbols

/// Why a streaming attempt finished, which decides whether and how soon to retry.
private enum StreamOutcome {
    /// Reached the streaming stage and it ended — reconnect promptly.
    case ended
    /// Never got that far. Back off before trying again.
    case failed
    /// Nothing to stream until preferences change; stop retrying.
    case idle
}

/// A sitemap `Text` widget and the linked page it wraps, shown as one header button.
private struct SitemapGroup {
    let id: String
    let title: String
    /// The `Text` widget itself, used for the button icon. nil for the synthesised Default.
    let source: OpenHABWidget?
    let widgets: [OpenHABWidget]
}

final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    static let defaultGroupId = "__default__"

    /// Names openHAB substitutes when a widget declares no icon of its own. Fetching these
    /// returns a generic glyph that reads as an empty box once template-rendered, so they
    /// resolve from the symbol map instead.
    static let placeholderIconNames: Set<String> = ["", "none", "text"]

    private var interfaceController: CPInterfaceController?
    private var streamTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var preferencesTask: Task<Void, Never>?
    private let sitemapEventStream = SitemapEventStream()
    private var currentListTemplate: CPListTemplate?
    /// Which sitemap group the header buttons currently have selected.
    private var activeGroupId: String?
    /// Identity of the rendered header buttons, so they are rebuilt only when they differ.
    private var headerButtonsSignature: String?
    private var currentTabBarTemplate: CPTabBarTemplate?
    private var groupTemplates: [String: CPListTemplate] = [:]
    private var currentGroupIds: [String] = []
    /// openHAB scopes an SSE subscription to a single page, so only the visible tab can be
    /// live. nil means the sitemap's home page.
    private var subscribedPageId: String?
    private let setpointService = SetPointService()
    // Retained across SSE restarts so page refreshes don't need a full stream teardown.
    private var currentPage: OpenHABPage?
    private var currentService: OpenAPIService?
    private var currentConnection: ConnectionInfo?
    private var iconTask: Task<Void, Never>?
    /// Keyed by icon URL so re-renders on every state event resolve synchronously and
    /// don't flicker back to the SF Symbol placeholder.
    private var iconCache: [String: UIImage] = [:]

    /// Exponential backoff capped at 30s. A stream that ran and then ended reconnects
    /// promptly; repeated failures — no signal, server unreachable — stop hammering a
    /// network that isn't there. Without this a single failure left CarPlay dead until the
    /// scene reconnected, because every error path simply returned.
    static func retryDelay(failures: Int) -> Int {
        guard failures > 0 else { return 2 }
        return min(30, 1 << min(failures, 5))
    }

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
        iconTask?.cancel()
        iconTask = nil
        Task { await sitemapEventStream.stop() }
        self.interfaceController = nil
        currentListTemplate = nil
        currentTabBarTemplate = nil
        groupTemplates.removeAll()
        currentGroupIds.removeAll()
        activeGroupId = nil
        headerButtonsSignature = nil
        currentPage = nil
        currentService = nil
        currentConnection = nil
        iconCache.removeAll()
        Logger.carPlay.info("CarPlay scene disconnected")
    }

    // MARK: - Streaming

    private func startStreaming() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            var failures = 0
            while !Task.isCancelled {
                guard let self else { return }
                let outcome = await runStream()
                guard !Task.isCancelled else { return }
                switch outcome {
                case .idle:
                    // Nothing to stream until preferences change; the observer restarts us.
                    return
                case .ended:
                    failures = 0
                case .failed:
                    failures += 1
                }
                let delay = Self.retryDelay(failures: failures)
                Logger.carPlay.info("CarPlay stream ended (\(String(describing: outcome))), retrying in \(delay)s")
                try? await Task.sleep(for: .seconds(delay))
            }
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
                // Sitemap selection changed — full restart needed (different page/subscription).
                startStreaming()
            }
        }
    }

    @MainActor
    private func runStream() async -> StreamOutcome {
        let prefs = Preferences.shared.currentHomePreferences
        await NetworkTracker.shared.startTracking(connectionConfigurations: [
            prefs.localConnectionConfig,
            prefs.remoteConnectionConfig
        ])
        guard let connection = await NetworkTracker.shared.waitForActiveConnection() else {
            Logger.carPlay.warning("CarPlay: no active connection")
            showUnreachableIfEmpty()
            return .failed
        }
        let sitemapName = Preferences.shared.currentHomePreferences.sitemapForCarPlay
        guard !sitemapName.isEmpty else {
            Logger.carPlay.info("CarPlay: no sitemap configured")
            interfaceController?.setRootTemplate(
                placeholderTemplate(message: String(localized: "carplay_not_configured_detail")),
                animated: false, completion: nil
            )
            return .idle
        }
        do {
            let service = try OpenAPIService(connectionConfiguration: connection.configuration)
            currentService = service
            currentConnection = connection

            guard let page = try await fetchPage(sitemapName: sitemapName, service: service) else {
                showUnreachableIfEmpty()
                return .failed
            }
            currentPage = page
            updateTemplate(page: page, service: service)

            let serverProps = try? await service.getRoot()
            if serverProps?.hasSseSupport() == true {
                await runSSE(sitemapName: sitemapName, connection: connection)
            } else {
                await runLongPoll(sitemapName: sitemapName, pageId: page.pageId, service: service)
            }
            return .ended
        } catch {
            Logger.carPlay.error("CarPlay stream error: \(error)")
            showUnreachableIfEmpty()
            return .failed
        }
    }

    /// Only replaces the screen when there is nothing on it. Losing signal mid-drive should
    /// leave the last known state visible rather than blanking the controls.
    @MainActor
    private func showUnreachableIfEmpty() {
        guard currentListTemplate == nil, currentTabBarTemplate == nil else { return }
        interfaceController?.setRootTemplate(
            placeholderTemplate(message: String(localized: "carplay_unreachable")),
            animated: false, completion: nil
        )
    }

    @MainActor
    private func runSSE(sitemapName: String, connection: ConnectionInfo) async {
        await sitemapEventStream.startMonitoringNetworkIfNeeded(initialConnection: connection)
        let homePageId = currentPage.map { $0.pageId.isEmpty ? sitemapName : $0.pageId } ?? sitemapName
        let pageId = subscribedPageId ?? homePageId
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
            var result = page.apply(event: event)
            // apply(event:) descends into nested `widgets` but not into `linkedPage`, so
            // without this every state change inside a tab would force a full refetch.
            if result == .notFound {
                result = applyToLinkedPages(event: event, in: page)
            }
            switch result {
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

    /// Moves the SSE subscription to the given tab's page. openHAB scopes a subscription to
    /// one page, so widgets on the other tabs stop receiving events until they're selected —
    /// each switch refreshes first to pick up whatever was missed.
    @MainActor
    private func repointSubscription(to groupId: String) {
        // The synthesised Default group holds the home page's own widgets.
        let pageId: String? = groupId == Self.defaultGroupId ? nil : groupId
        guard pageId != subscribedPageId else { return }
        subscribedPageId = pageId

        // Reuse the retrying path so a tab switch in poor signal recovers like any other.
        startStreaming()
    }

    /// Fetches the whole sitemap rather than just its home page. `pollDataForPage` returns
    /// linked pages as stubs with no children, so tab content would come back empty.
    private func fetchPage(sitemapName: String, service: OpenAPIService) async throws -> OpenHABPage? {
        try await service.pollDataForSitemap(sitemapname: sitemapName)?.page
    }

    @MainActor
    private func applyToLinkedPages(event: OpenHABSitemapWidgetEvent,
                                    in page: OpenHABPage) -> SitemapWidgetEventApplicationResult {
        for widget in page.widgets {
            guard let linked = widget.linkedPage else { continue }
            let result = linked.apply(event: event)
            if result != .notFound { return result }
        }
        return .notFound
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
            guard let page = try await fetchPage(sitemapName: sitemapName, service: service) else { return }
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
}

// MARK: - Template building

extension CarPlaySceneDelegate {
    @MainActor
    private func updateTemplate(page: OpenHABPage, service: OpenAPIService) {
        let visible = page.widgets.filter(\.visibility)
        let groups = visible.compactMap(sitemapGroup(for:))
        // A Text widget that became a tab must not also appear as a row.
        let promoted = Set(groups.compactMap { $0.source?.widgetId })
        let rootWidgets = visible.filter { !promoted.contains($0.widgetId) && isCompatible($0) }

        guard !groups.isEmpty || !rootWidgets.isEmpty else {
            currentListTemplate = nil
            currentTabBarTemplate = nil
            groupTemplates.removeAll()
            currentGroupIds.removeAll()
            activeGroupId = nil
            headerButtonsSignature = nil
            interfaceController?.setRootTemplate(placeholderTemplate(), animated: false, completion: nil)
            return
        }

        // The nav bar has no font control, so a shorter string is the only lever. CarPlay
        // already identifies the app in its own chrome, making an "openHAB" prefix redundant.
        let title = page.title.isEmpty ? "openHAB" : page.title

        if groups.isEmpty {
            renderList(title: title, widgets: rootWidgets, service: service)
        } else {
            // Loose widgets alongside grouped ones need somewhere to live.
            let sections = rootWidgets.isEmpty
                ? groups
                : [SitemapGroup(
                    id: Self.defaultGroupId,
                    title: String(localized: "carplay_default_tab"),
                    source: nil,
                    widgets: rootWidgets
                )] + groups
            if #available(iOS 26.0, *), anyGroupHasIcon(sections) {
                renderGroupedList(title: title, groups: sections, service: service)
            } else {
                // Nothing to illustrate, or no header buttons on this system.
                renderTabBar(groups: sections, service: service)
            }
        }

        fetchRemoteIcons(for: visible + groups.flatMap(\.widgets), page: page, service: service)
    }

    /// A `Text` widget wrapping a linked page becomes a group. The root sitemap response
    /// already carries the linked page's widgets, so no extra fetch is needed.
    private func sitemapGroup(for widget: OpenHABWidget) -> SitemapGroup? {
        guard let linked = widget.linkedPage else { return nil }
        let widgets = linked.widgets.filter { $0.visibility && isCompatible($0) }
        guard !widgets.isEmpty else { return nil }
        return SitemapGroup(
            id: linked.pageId.isEmpty ? widget.widgetId : linked.pageId,
            title: widget.displayState.labelText,
            source: widget,
            widgets: widgets
        )
    }

    /// Widgets we can represent. Rollershutters are left out deliberately: they need
    /// UP/STOP/DOWN, and falling through to an ON/OFF toggle would send the wrong command.
    private func isCompatible(_ widget: OpenHABWidget) -> Bool {
        guard widget.item != nil else { return false }
        switch widget.renderingKind {
        case .toggleSwitch, .segmentedSwitch:
            return widget.type == .switchWidget
        case .setpoint:
            return true
        case .text:
            // A Text widget with an item is a read-only value display. Ones that wrap a
            // linked page became tabs and were filtered out before this point.
            return true
        default:
            return false
        }
    }

    // MARK: - Group navigation

    /// True when at least one group carries a real sitemap icon. Header buttons trade
    /// vertical space for artwork, which is only worth it if there is artwork to show;
    /// otherwise the tab bar gives the same navigation in less room.
    private func anyGroupHasIcon(_ groups: [SitemapGroup]) -> Bool {
        groups.contains { group in
            guard let widget = group.source else { return false }
            return !Self.placeholderIconNames.contains(widget.icon.lowercased())
        }
    }

    /// A row of header buttons, one per sitemap group, above the selected group's widgets.
    /// `CPGridButton` draws its image and title together, which the tab bar refuses to do —
    /// give a tab a title and its image is dropped at any size.
    @available(iOS 26.0, *)
    @MainActor
    private func renderGroupedList(title: String, groups: [SitemapGroup], service: OpenAPIService) {
        let cap = CPListTemplate.maximumHeaderGridButtonCount
        let shown = Array(groups.prefix(cap))
        if shown.count < groups.count {
            Logger.carPlay.info("CarPlay: \(groups.count - shown.count) group(s) dropped, cap is \(cap)")
        }
        guard let active = shown.first(where: { $0.id == activeGroupId }) ?? shown.first else { return }
        activeGroupId = active.id

        // The list title is read-only after creation, so the section header carries the
        // selected group's name — the buttons themselves show no selected state.
        let section = CPListSection(
            items: active.widgets.map { makeListItem(for: $0, service: service) },
            header: active.title,
            sectionIndexTitle: nil
        )

        let template: CPListTemplate
        if let existing = currentListTemplate {
            existing.updateSections([section])
            template = existing
        } else {
            template = CPListTemplate(title: title, sections: [section])
            currentListTemplate = template
            interfaceController?.setRootTemplate(template, animated: false, completion: nil)
            repointSubscription(to: active.id)
        }

        // Rebuilding the header on every state event makes it flicker and shifts the list
        // under it, so only touch it when the buttons would actually differ.
        let signature = shown.map { "\($0.id)|\($0.title)|\($0.source?.icon ?? "")" }.joined(separator: ",")
        guard signature != headerButtonsSignature else { return }
        headerButtonsSignature = signature

        let point = min(
            CPListTemplate.maximumGridButtonImageSize.width,
            CPListTemplate.maximumGridButtonImageSize.height
        )
        template.headerGridButtons = shown.map { group in
            CPGridButton(
                titleVariants: [group.title],
                image: groupImage(for: group, size: point)
            ) { [weak self] _ in
                self?.selectGroup(group.id)
            }
        }
    }

    @MainActor
    private func selectGroup(_ id: String) {
        guard id != activeGroupId else { return }
        activeGroupId = id
        Logger.carPlay.info("CarPlay group selected: \(id)")
        // Repointing refetches and re-renders, which redraws the list for the new group.
        repointSubscription(to: id)
    }

    /// Tab bar navigation: one tab per group, labelled but without artwork. Used when no
    /// group has an icon worth showing, and on systems without header buttons.
    @MainActor
    private func renderTabBar(groups: [SitemapGroup], service: OpenAPIService) {
        let cap = CPTabBarTemplate.maximumTabCount
        let shown = Array(groups.prefix(cap))
        if shown.count < groups.count {
            Logger.carPlay.info("CarPlay: \(groups.count - shown.count) tab(s) dropped, cap is \(cap)")
        }

        var templates: [CPListTemplate] = []
        for group in shown {
            let section = CPListSection(items: group.widgets.map { makeListItem(for: $0, service: service) })
            if let existing = groupTemplates[group.id] {
                existing.updateSections([section])
                templates.append(existing)
            } else {
                // Title only: the tab bar drops any image once a title is present.
                let template = CPListTemplate(title: group.title, sections: [section])
                groupTemplates[group.id] = template
                templates.append(template)
            }
        }

        // Replacing templates resets the driver's selected tab, so only when the set changes.
        let ids = shown.map(\.id)
        guard ids != currentGroupIds else { return }
        currentGroupIds = ids
        groupTemplates = groupTemplates.filter { ids.contains($0.key) }

        if let existing = currentTabBarTemplate {
            existing.updateTemplates(templates)
        } else {
            let tabBar = CPTabBarTemplate(templates: templates)
            tabBar.delegate = self
            currentTabBarTemplate = tabBar
            currentListTemplate = nil
            interfaceController?.setRootTemplate(tabBar, animated: false, completion: nil)
            if let first = shown.first { repointSubscription(to: first.id) }
        }
    }

    // MARK: - List rendering

    @MainActor
    private func renderList(title: String, widgets: [OpenHABWidget], service: OpenAPIService) {
        let section = CPListSection(items: widgets.map { makeListItem(for: $0, service: service) })

        if let existing = currentListTemplate {
            // CPListTemplate.title is read-only, so a renamed page keeps its original title
            // until the scene reconnects. Rebuilding here would reset scroll position.
            existing.updateSections([section])
        } else {
            let template = CPListTemplate(title: title, sections: [section])
            currentListTemplate = template
            interfaceController?.setRootTemplate(template, animated: false, completion: nil)
        }
    }

    /// Every widget is one row. A widget with a choice of commands opens an action sheet
    /// rather than crowding the row with a button per command.
    @MainActor
    private func makeListItem(for widget: OpenHABWidget, service: OpenAPIService) -> any CPListTemplateItem {
        switch widget.renderingKind {
        case .setpoint:
            return makeSetpointItem(for: widget, service: service)
        case .text:
            return makeTextItem(for: widget)
        default:
            break
        }

        // renderingKind is the app's own precedence: explicit sitemap mappings win, then a
        // Switch item is a toggle regardless of any state options the binding advertises.
        guard widget.renderingKind == .segmentedSwitch else {
            return makeToggleItem(for: widget, service: service)
        }

        let mappings = widget.displayState.mappings
        // A single press/release mapping is a momentary button, not a choice.
        guard mappings.count > 1 || (mappings.count == 1 && !mappings[0].hasPressReleaseBehavior) else {
            return makeToggleItem(for: widget, service: service)
        }
        return makeActionSheetItem(for: widget, mappings: mappings, service: service)
    }

    /// CarPlay has no stepper. On iOS 26 the row carries its own inline − / + buttons so
    /// the driver can step repeatedly without a modal; older systems fall back to a sheet,
    /// which closes after each tap because action sheets are single-choice by design.
    @MainActor
    private func makeSetpointItem(for widget: OpenHABWidget, service: OpenAPIService) -> any CPListTemplateItem {
        if #available(iOS 26.0, *) {
            return makeSetpointRow(for: widget, service: service)
        }
        let ds = widget.displayState
        let item = CPListItem(
            text: ds.labelText,
            detailText: setpointValueText(ds),
            image: iconImage(for: widget, size: rowIconPointSize),
            accessoryImage: nil,
            accessoryType: .disclosureIndicator
        )
        item.handler = { [weak self] _, completion in
            guard let self else { return completion() }
            presentSetpointSheet(for: widget, service: service)
            completion()
        }
        return item
    }

    @available(iOS 26.0, *)
    @MainActor
    private func makeSetpointRow(for widget: OpenHABWidget, service: OpenAPIService) -> CPListImageRowItem {
        let ds = widget.displayState
        let stepText = ds.step.valueText(step: ds.step)
        let size = rowIconPointSize

        let elements = [
            CPListImageRowItemImageGridElement(
                image: sfSymbolImage(.minusCircle, pointSize: size),
                imageShape: .circular,
                title: "− \(stepText)",
                accessorySymbolName: nil
            ),
            CPListImageRowItemImageGridElement(
                image: sfSymbolImage(.plusCircle, pointSize: size),
                imageShape: .circular,
                title: "+ \(stepText)",
                accessorySymbolName: nil
            )
        ]

        let row = CPListImageRowItem(
            text: "\(ds.labelText)  \(setpointValueText(ds))",
            imageGridElements: elements,
            allowsMultipleLines: false
        )
        row.listImageRowHandler = { [weak self] _, index, completion in
            self?.sendSetpoint(for: widget, decreasing: index == 0, service: service)
            completion()
        }
        return row
    }

    private func setpointValueText(_ ds: WidgetDisplayState) -> String {
        ds.labelValue ?? ds.adjustedValue.valueText(step: ds.step)
    }

    @MainActor
    private func presentSetpointSheet(for widget: OpenHABWidget, service: OpenAPIService) {
        let ds = widget.displayState
        let stepText = ds.step.valueText(step: ds.step)

        func action(decreasing: Bool) -> CPAlertAction {
            CPAlertAction(title: decreasing ? "− \(stepText)" : "+ \(stepText)", style: .default) { [weak self] _ in
                self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
                self?.sendSetpoint(for: widget, decreasing: decreasing, service: service)
            }
        }

        let sheet = CPActionSheetTemplate(
            title: ds.labelText,
            message: setpointValueText(ds),
            actions: [
                action(decreasing: false),
                action(decreasing: true),
                CPAlertAction(title: String(localized: "Cancel"), style: .cancel) { [weak self] _ in
                    self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
                }
            ]
        )
        interfaceController?.presentTemplate(sheet, animated: true, completion: nil)
    }

    @MainActor
    private func sendSetpoint(for widget: OpenHABWidget, decreasing: Bool, service: OpenAPIService) {
        let ds = widget.displayState
        let newValue = setpointService.calculateNewValue(
            currentValue: ds.adjustedValue,
            step: ds.step,
            minValue: ds.minValue,
            maxValue: ds.maxValue,
            isDecreasing: decreasing
        )
        guard newValue != ds.adjustedValue, let name = widget.item?.name else { return }

        // commandString is the wire format; toString(locale:) is for display and would send
        // a pattern-formatted, locale-decimal string the server rejects.
        let command = NumberState(value: newValue, unit: widget.unit).commandString
        Task {
            do {
                try await service.sendItemCommand(itemname: name, command: command)
            } catch {
                Logger.carPlay.error("CarPlay setpoint \(name) = \(command) failed: \(error)")
            }
        }
    }

    /// A read-only value row.
    @MainActor
    private func makeTextItem(for widget: OpenHABWidget) -> CPListItem {
        let ds = widget.displayState
        let item = CPListItem(
            text: ds.labelText,
            detailText: ds.labelValue ?? ds.effectiveState,
            image: iconImage(for: widget, size: rowIconPointSize),
            accessoryImage: nil,
            accessoryType: .none
        )
        // Rows stay selectable even with no action, and CarPlay spins until the completion
        // block runs — so a nil handler leaves the spinner turning forever.
        item.handler = { _, completion in completion() }
        return item
    }

    @MainActor
    private func makeToggleItem(for widget: OpenHABWidget, service: OpenAPIService) -> CPListItem {
        let ds = widget.displayState
        // Deliberately not selectedLabel: a toggle has no meaningful mapping selection, and
        // state options from the binding would surface as "True"/"False" here.
        let item = CPListItem(
            text: ds.labelText,
            detailText: ds.labelValue ?? ds.effectiveState,
            image: iconImage(for: widget, size: rowIconPointSize),
            accessoryImage: nil,
            accessoryType: .none
        )
        item.handler = { [weak self] _, completion in
            self?.sendDefaultAction(for: widget, service: service)
            completion()
        }
        return item
    }

    @MainActor
    private func makeActionSheetItem(for widget: OpenHABWidget,
                                     mappings: [OpenHABWidgetMapping],
                                     service: OpenAPIService) -> CPListItem {
        let ds = widget.displayState
        let item = CPListItem(
            text: ds.labelText,
            detailText: ds.selectedLabel ?? ds.effectiveState,
            image: iconImage(for: widget, size: rowIconPointSize),
            accessoryImage: nil,
            accessoryType: .disclosureIndicator
        )
        item.handler = { [weak self] _, completion in
            guard let self else { return completion() }
            var actions = mappings.map { mapping in
                CPAlertAction(title: mapping.label, style: .default) { [weak self] _ in
                    self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
                    self?.send(mapping: mapping, for: widget, service: service)
                }
            }
            actions.append(CPAlertAction(title: String(localized: "Cancel"), style: .cancel) { [weak self] _ in
                self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
            })
            let sheet = CPActionSheetTemplate(title: ds.labelText, message: nil, actions: actions)
            interfaceController?.presentTemplate(sheet, animated: true, completion: nil)
            completion()
        }
        return item
    }

    // MARK: - Commands

    /// Sends a single mapping's command, honouring press/release pairs.
    @MainActor
    private func send(mapping: OpenHABWidgetMapping, for widget: OpenHABWidget, service: OpenAPIService) {
        guard let name = widget.item?.name else { return }
        Task {
            if !mapping.command.isEmpty {
                try? await service.sendItemCommand(itemname: name, command: mapping.command)
            }
            if let release = mapping.releaseCommand, !release.isEmpty {
                try? await Task.sleep(for: .milliseconds(500))
                try? await service.sendItemCommand(itemname: name, command: release)
            }
        }
    }

    /// Toggle behaviour for widgets without a choice of commands.
    @MainActor
    private func sendDefaultAction(for widget: OpenHABWidget, service: OpenAPIService) {
        let ds = widget.displayState
        Task {
            guard let name = widget.item?.name else { return }
            // Resolve press/release source: single mapping takes precedence over widget-level fields
            let pressCommand: String?
            let releaseCommand: String?
            if let mapping = ds.mappings.first, mapping.hasPressReleaseBehavior {
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
                try? await service.sendItemCommand(itemname: name, command: ds.isOn ? "OFF" : "ON")
            }
        }
    }
}

// MARK: - Icons

extension CarPlaySceneDelegate {
    /// Point size for list row images, in CarPlay's own units.
    private var rowIconPointSize: CGFloat {
        let size = CPListItem.maximumImageSize
        return min(size.width, size.height)
    }

    /// The head unit's scale, used to render server icons at native resolution.
    private var carDisplayScale: CGFloat {
        let scale = interfaceController?.carTraitCollection.displayScale ?? 0
        return scale > 0 ? scale : 2
    }

    private static func fetchIcon(url: URL, connection: ConnectionInfo, pixelSize: CGFloat) async -> UIImage? {
        let options: KingfisherOptionsInfo = [
            .processor(OpenHABImageProcessor(svgMaxSize: CGSize(width: pixelSize, height: pixelSize))),
            .requestModifier(OpenHABAccessTokenAdapter(connectionConfiguration: connection.configuration))
        ]
        guard let image = try? await KingfisherManager.shared.retrieveImage(with: url, options: options).image else {
            return nil
        }
        // Server icons carry their own colours — template rendering would flatten them to a single tint.
        return image.withRenderingMode(.alwaysOriginal)
    }

    /// Server icons are preferred so user-defined and state-dependent icons render as the
    /// sitemap authored them. The SF Symbol is the synchronous placeholder shown until the
    /// fetch lands, and the permanent fallback when there is no icon to fetch.
    @MainActor
    private func iconImage(for widget: OpenHABWidget,
                           mapping: OpenHABWidgetMapping? = nil,
                           size pointSize: CGFloat) -> UIImage {
        let name = mapping?.icon ?? widget.icon
        if let url = iconURL(name: name, widget: widget),
           let cached = iconCache[url.absoluteString] {
            return resized(cached, toFit: pointSize)
        }
        return sfSymbol(named: name, isOn: widget.displayState.isOn, pointSize: pointSize)
    }

    /// Fetched icons arrive at the pixel size we asked the processor for but report scale 1,
    /// so a 264px bitmap claims to be 264 points — far past what a tab or row expects, and
    /// CarPlay drops images that overshoot. Redraw to the target point size at the car's
    /// scale, preserving aspect ratio and rendering mode.
    @MainActor
    private func resized(_ image: UIImage, toFit pointSize: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > pointSize, longest > 0 else { return image }

        let ratio = pointSize / longest
        let target = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = carDisplayScale
        format.opaque = false
        let drawn = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return drawn.withRenderingMode(image.renderingMode)
    }

    /// The system retints header button images, so they have to be template-rendered —
    /// a full-colour server icon is either ignored or flattened to a silhouette.
    @MainActor
    private func groupImage(for group: SitemapGroup, size: CGFloat) -> UIImage {
        // The synthesised Default group has no widget; a group whose sitemap entry declares
        // no icon gets openHAB's placeholder name, which is no more useful. Both fall back
        // to a neutral folder rather than an empty box.
        guard let widget = group.source,
              !Self.placeholderIconNames.contains(widget.icon.lowercased()) else {
            return sfSymbolImage(group.id == Self.defaultGroupId ? .house : .folder, pointSize: size)
        }
        return iconImage(for: widget, size: size).withRenderingMode(.alwaysTemplate)
    }

    private func sfSymbolImage(_ symbol: SFSymbol, pointSize: CGFloat) -> UIImage {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        return UIImage(systemSymbol: symbol)
            .applyingSymbolConfiguration(config)?
            .withRenderingMode(.alwaysTemplate)
            ?? UIImage(systemSymbol: symbol).withRenderingMode(.alwaysTemplate)
    }

    private func sfSymbol(named name: String, isOn: Bool, pointSize: CGFloat) -> UIImage {
        let symbol = openHABSFSymbol(for: name, isOn: isOn)
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        return UIImage(systemSymbol: symbol)
            .applyingSymbolConfiguration(config)?
            .withRenderingMode(.alwaysTemplate)
            ?? UIImage(systemSymbol: symbol).withRenderingMode(.alwaysTemplate)
    }

    /// `none` is openHAB's explicit "no icon" and resolves to an empty document, so it is
    /// never worth a round trip.
    @MainActor
    private func iconURL(name: String, widget: OpenHABWidget) -> URL? {
        guard !Self.placeholderIconNames.contains(name.lowercased()),
              let connection = currentConnection else { return nil }
        return Endpoint.icon(
            rootUrl: connection.configuration.url,
            version: connection.version,
            icon: name,
            state: widget.iconState(),
            iconType: .png,
            iconColor: widget.iconColor,
            staticIcon: widget.staticIcon
        )?.url
    }

    /// Fetches any icons not already cached, then re-renders. Terminates because the second
    /// render finds every URL cached and requests nothing further.
    @MainActor
    private func fetchRemoteIcons(for widgets: [OpenHABWidget], page: OpenHABPage, service: OpenAPIService) {
        guard let connection = currentConnection else { return }

        var urls: Set<URL> = []
        for widget in widgets {
            let names = [widget.icon] + widget.displayState.mappings.compactMap(\.icon)
            for name in names {
                if let url = iconURL(name: name, widget: widget), iconCache[url.absoluteString] == nil {
                    urls.insert(url)
                }
            }
        }
        guard !urls.isEmpty else { return }

        let pixelSize = (rowIconPointSize * carDisplayScale).rounded()
        iconTask?.cancel()
        iconTask = Task { [weak self] in
            var fetched: [String: UIImage] = [:]
            for url in urls {
                guard !Task.isCancelled else { return }
                if let image = await Self.fetchIcon(url: url, connection: connection, pixelSize: pixelSize) {
                    fetched[url.absoluteString] = image
                }
            }
            guard !Task.isCancelled, !fetched.isEmpty else { return }
            await MainActor.run {
                guard let self else { return }
                self.iconCache.merge(fetched) { _, new in new }
                // Only repaint if this is still the page on screen.
                guard self.currentPage?.pageId == page.pageId else { return }
                self.updateTemplate(page: page, service: service)
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

// MARK: - CPTabBarTemplateDelegate

extension CarPlaySceneDelegate: CPTabBarTemplateDelegate {
    func tabBarTemplate(_ tabBarTemplate: CPTabBarTemplate, didSelect selectedTemplate: CPTemplate) {
        guard let id = groupTemplates.first(where: { $0.value === selectedTemplate })?.key else { return }
        Logger.carPlay.info("CarPlay tab selected: \(id)")
        repointSubscription(to: id)
    }
}
