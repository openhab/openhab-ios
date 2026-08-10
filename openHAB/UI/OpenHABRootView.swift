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
import Kingfisher
import OpenHABCore
import os.log
import SafariServices
import SFSafeSymbols
import SwiftUI

struct OpenHABRootView: View {
    @StateObject private var networkService = NetworkConnectionService()
    @StateObject private var notificationService = NotificationActionService()
    @StateObject private var pushService = PushRegistrationService()
    @StateObject private var crashService = CrashReportService()
    @StateObject private var menuData = MenuDataService()
    @StateObject private var webViewModel = OpenHABWebViewModel()
    @State private var menuPresented = false
    @State private var navbarActionsPresented = false
    @State private var currentContent: TargetController = .webview
    @State private var currentViewTitle: String = ""
    @State private var activeNetworkConnection: ConnectionInfo? = MainActorNetworkTracker.shared.activeConnection
    @State private var showNotifications = false
    @State private var sitemapResetID = UUID()

    var body: some View {
        ZStack {
            contentView

            // Toolbar menu overlay
            ToolbarMenu(
                isPresented: $menuPresented,
                menuData: menuData,
                onSelect: { target in handleMenuSelection(target) },
                onReload: { reloadCurrentContent() }
            )
        }
        .onAppear {
            #if DEBUG
            let env = ProcessInfo.processInfo.environment
            if env["UITest"] != nil {
                Preferences.shared.modifyActiveHome { $0.demomode = true }
            }
            if let title = env["UITestToastTitle"],
               let message = env["UITestToastMessage"] {
                let actions: [NotificationActionItem]
                if let actionsJSON = env["UITestToastActions"],
                   let data = actionsJSON.data(using: .utf8),
                   let items = try? JSONDecoder().decode([NotificationActionItem].self, from: data) {
                    actions = items
                } else {
                    actions = []
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    ToastService.shared.show(title: title, message: message, actions: actions)
                }
            }
            if env["UITestNotifications"] != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showNotifications = true
                }
            }
            if env["UITestWebViewMode"] != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    currentContent = .webview
                }
                if let encoded = env["UITestInjectHTML"],
                   let data = Data(base64Encoded: encoded),
                   let html = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        webViewModel.loadHTMLString(html)
                    }
                }
            }
            if let json = env["UITestWebViewNavbarItems"],
               let data = json.data(using: .utf8),
               let raw = try? JSONDecoder().decode([[String: String]].self, from: data) {
                let items = raw.compactMap { d -> WebNavbarItem? in
                    guard let label = d["label"], let action = d["jsAction"] else { return nil }
                    return WebNavbarItem(label: label, jsAction: action, iconBase64: nil, isBack: false)
                }
                webViewModel.lockUITestContent()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    webViewModel.updateNavbarItems(items)
                }
            }
            #endif
            ImageDownloader.default.authenticationChallengeResponder = networkService
            switchToSavedView()
            setupExitToApp()
        }
        .onReceive(notificationService.$navigationCommand.compactMap { $0 }) { command in
            handleNavigationCommand(command)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("org.openhab.preferences.saved"))) { _ in
            menuData.refresh()
            webViewModel.reloadView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .homeDidSwitch)) { _ in
            menuData.clearAll()
            switchToSavedView()
            // Reconcile the web view with the new home: loads if the active connection
            // already belongs to it (e.g. between two demo homes), otherwise blanks and
            // waits for the tracker to connect the new home.
            webViewModel.syncActiveConnection()
        }
        .task {
            for await connection in MainActorNetworkTracker.shared.$activeConnection.values {
                activeNetworkConnection = connection
            }
        }
        .sheet(isPresented: $showNotifications) {
            NavigationView { NotificationsView() }
        }
        .alert(
            networkService.certificateAlert?.title ?? "",
            isPresented: Binding(
                get: { networkService.certificateAlert != nil },
                set: { if !$0 { networkService.certificateAlert = nil } }
            )
        ) {
            Button("Always") { networkService.certificateAlertAction(.permitAlways) }
            Button("Once") { networkService.certificateAlertAction(.permitOnce) }
            Button("Deny", role: .cancel) { networkService.certificateAlertAction(.deny) }
        } message: {
            Text(networkService.certificateAlert?.message ?? "")
        }
        .alert("Crash Report", isPresented: $crashService.crashReportAlert) {
            Button("Send") { crashService.enableCrashReporting() }
            Button("Don't Send", role: .cancel) { crashService.deleteCrashReports() }
        } message: {
            Text("The app crashed during the previous session. Would you like to send a crash report?")
        }
        .overlay(alignment: .bottom) {
            InAppToastBanner(service: ToastService.shared)
        }
        #if DEBUG
        .overlay {
            ForEach(Array(webViewModel.uiTestReports.keys.sorted()), id: \.self) { key in
                Text(webViewModel.uiTestReports[key] ?? "")
                    .accessibilityIdentifier("UITestReport-\(key)")
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .allowsHitTesting(false)
            }
            Text(String(webViewModel.navbarItems.count))
                .accessibilityIdentifier("UITestReport-navbarItemCount")
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
        }
        #endif
    }

    // MARK: - Content switching

    @ViewBuilder
    private var contentView: some View {
        switch currentContent {
        case .webview, .mainUIPage:
            ZStack(alignment: .top) {
                OpenHABWebViewContainer(viewModel: webViewModel)
                    .padding(.top, 44)
                    .background(.clear)
                // Placeholder while a home is first loading. Sits above the (transparent)
                // web view but below the menu bar, so the menu stays reachable and the user
                // can switch homes even while connecting.
                if !webViewModel.hasLoadedContent {
                    ConnectingPlaceholder()
                        .transition(.opacity)
                }
                menuBar
            }
            .animation(.easeInOut(duration: 0.25), value: webViewModel.hasLoadedContent)
            .onAppear { webViewModel.triggerAppMenuProbe() }
        case let .sitemap(name):
            SitemapNavigationView(onShowSideMenu: { menuPresented = true })
                .id("\(name)-\(sitemapResetID)")
        case .tile:
            VStack(spacing: 0) {
                menuBar
                OpenHABWebViewContainer(viewModel: webViewModel)
            }
        case .notifications, .browser:
            preconditionFailure("Modal/transient targets must never become currentContent")
        }
    }

    @ViewBuilder
    private var menuBar: some View {
        let isWebviewMode: Bool = {
            switch currentContent {
            case .webview, .mainUIPage: return true
            default: return false
            }
        }()

        let barTitle: String = {
            if isWebviewMode { return webViewModel.navbarTitle }
            if case .tile = currentContent { return currentViewTitle }
            return ""
        }()

        HStack {
            // Left side: proxied navbar items (webview mode with items available),
            // or connection-status indicator as fallback.
            Group {
                if isWebviewMode, !webViewModel.navbarItems.isEmpty {
                    let backItem = webViewModel.navbarItems.first { $0.isBack }
                    let otherItems = webViewModel.navbarItems.filter { !$0.isBack }
                    HStack(spacing: 4) {
                        // Back button is always shown directly in the bar when present.
                        if let backItem {
                            navbarProxyButton(backItem)
                        }
                        // When a back button is present, remaining items always go in a
                        // popover — even a single item, which may be text-only and too wide
                        // to sit next to the back button and the hamburger.
                        // Without a back button, a single item is shown directly.
                        if !otherItems.isEmpty {
                            if backItem != nil || otherItems.count > 1 {
                                navbarActionsButton(otherItems)
                            } else if let single = otherItems.first {
                                navbarProxyButton(single)
                            }
                        }
                    }
                } else if isWebviewMode, activeNetworkConnection == nil {
                    HStack(spacing: 4) {
                        Image(systemSymbol: .wifiExclamationmark)
                        Text("Offline")
                            .ohTextToken(.secondary)
                        Button { reloadCurrentContent() } label: {
                            Image(systemSymbol: .arrowClockwise)
                        }
                    }
                    .foregroundStyle(.secondary)
                } else if webViewModel.isLoading {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Connecting")
                            .ohTextToken(.secondary)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.leading)

            Spacer()

            Group {
                if #available(iOS 26, *) {
                    Button {
                        menuPresented = true
                    } label: {
                        Image(systemSymbol: .line3Horizontal)
                            .font(.title)
                    }
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("HamburgerButton")
                    .accessibilityLabel("Menu")
                    .padding(.trailing)
                } else {
                    Button {
                        menuPresented = true
                    } label: {
                        Image(systemSymbol: .line3Horizontal)
                            .font(.title)
                    }
                    .accessibilityIdentifier("HamburgerButton")
                    .accessibilityLabel("Menu")
                    .padding(.trailing)
                }
            }
            .scaleEffect(menuPresented ? 3.0 : 1.0, anchor: .topTrailing)
            .opacity(menuPresented ? 0.0 : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: menuPresented)
        }
        .frame(height: 44)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("MainMenuBar")
        .overlay {
            if !barTitle.isEmpty {
                Text(barTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: 200)
                    .allowsHitTesting(false)
            }
        }
        .background(
            isWebviewMode
                ? AnyShapeStyle(.bar)
                : AnyShapeStyle(Color(.systemBackground)),
            ignoresSafeAreaEdges: .top
        )
    }

    // MARK: - Navbar proxy helpers

    @ViewBuilder
    private func navbarProxyButton(_ item: WebNavbarItem) -> some View {
        Button {
            webViewModel.evaluateJS(item.jsAction)
        } label: {
            if let uiImg = item.iconImage {
                Image(uiImage: uiImg)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
            } else {
                Text(item.label)
            }
        }
        .accessibilityLabel(item.label)
        .accessibilityIdentifier("NavbarProxyButton-\(item.label)")
    }

    @ViewBuilder
    private func navbarActionsButton(_ items: [WebNavbarItem]) -> some View {
        Button {
            navbarActionsPresented = true
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title2)
        }
        .accessibilityLabel("Actions")
        .accessibilityIdentifier("NavbarActionsMenu")
        .popover(isPresented: $navbarActionsPresented) {
            HStack(spacing: 20) {
                ForEach(items) { item in
                    Button {
                        webViewModel.evaluateJS(item.jsAction)
                        navbarActionsPresented = false
                    } label: {
                        if let uiImg = item.iconImage {
                            Image(uiImage: uiImg)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                        } else {
                            Text(item.label)
                        }
                    }
                    .accessibilityLabel(item.label)
                    .accessibilityIdentifier("NavbarProxyButton-\(item.label)")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .presentationDetents([.height(72)])
            .presentationCompactAdaptation(.popover)
        }
    }

    private func switchToSavedView() {
        // Select the surface for the current home. Demo homes follow their defaultView like
        // any other home. The web view's actual load is driven by syncActiveConnection, so
        // here we only choose which content is shown.
        let prefs = Preferences.shared.currentHomePreferences
        if prefs.defaultView == "sitemap" {
            switchContent(to: .sitemap(prefs.defaultSitemap))
        } else {
            currentContent = .webview
        }
    }

    private func switchContent(to newContent: TargetController) {
        if currentContent == newContent {
            // Tapped same item — reload
            switch newContent {
            case .webview:
                webViewModel.reloadView()
            case .sitemap:
                sitemapResetID = UUID() // pop to root by recreating the NavigationStack
            case let .tile(url):
                if let url = URL(string: url) {
                    webViewModel.loadTilePage(url)
                }
            default:
                break // modal/transient targets never reach switchContent
            }
        } else {
            let wasShowingTile: Bool
            if case .tile = currentContent { wasShowingTile = true } else { wasShowingTile = false }

            currentContent = newContent

            switch newContent {
            case .webview:
                if wasShowingTile { webViewModel.reloadView() }
            case .sitemap:
                break
            case let .tile(url):
                if let url = URL(string: url) {
                    webViewModel.loadTilePage(url)
                }
            default:
                break // modal/transient targets never reach switchContent
            }

            if !Preferences.shared.currentHomePreferences.demomode {
                let viewName: String
                switch newContent {
                case .webview: viewName = "web"
                case .sitemap: viewName = "sitemap"
                case .tile: viewName = "web" // treat tile as web for persistence
                default: return // modal/transient targets never reach switchContent
                }
                Preferences.shared.modifyActiveHome { $0.defaultView = viewName }
            }
        }
    }

    // MARK: - Menu handling

    private func handleMenuSelection(_ target: TargetController) {
        switch target {
        case .webview:
            showMainUI(path: nil)
        case let .mainUIPage(path):
            showMainUI(path: path)
        case let .sitemap(name):
            Preferences.shared.modifyActiveHome { $0.defaultSitemap = name }
            switchContent(to: .sitemap(name))
        case .notifications:
            showNotifications = true
        case let .tile(urlString):
            currentViewTitle = menuData.label(forURL: urlString)
            switchToTile(urlString)
        case let .browser(urlString):
            if let url = URL(string: urlString) {
                openSafari(url: url)
            }
        }
    }

    /// Shows the MainUI web surface at `path` (nil = the MainUI root). When the SPA is
    /// already live it routes client-side through the page's own Framework7 router, so
    /// no full page load happens and in-app state is preserved; otherwise it loads the
    /// URL at that path and Framework7 routes to it on startup. The chosen destination
    /// is recorded as `currentContent` so a later reload returns here rather than to an
    /// arbitrary route the user reached inside the SPA.
    private func showMainUI(path: String?) {
        currentContent = path.map(TargetController.mainUIPage) ?? .webview
        if webViewModel.isMainUIReady {
            webViewModel.navigateCommand("navigate:\(path ?? "/")")
        } else {
            webViewModel.loadWebView(force: false, path: path)
        }
        persistDefaultViewIfNeeded("web")
    }

    private var isMainUIShown: Bool {
        switch currentContent {
        case .webview, .mainUIPage: return true
        default: return false
        }
    }

    /// Persists the home's default view only when it actually changes, avoiding a
    /// redundant preferences write (which would otherwise restart network tracking).
    private func persistDefaultViewIfNeeded(_ viewName: String) {
        guard !Preferences.shared.currentHomePreferences.demomode else { return }
        guard Preferences.shared.currentHomePreferences.defaultView != viewName else { return }
        Preferences.shared.modifyActiveHome { $0.defaultView = viewName }
    }

    /// Reloads the destination currently selected in the menu — never the arbitrary
    /// route the user may have reached inside the SPA — so a reload always lands
    /// somewhere the menu can navigate away from.
    private func reloadCurrentContent() {
        switch currentContent {
        case .webview:
            webViewModel.loadWebView(force: true, path: nil)
        case let .mainUIPage(path):
            webViewModel.loadWebView(force: true, path: path)
        case let .tile(urlString):
            if let url = URL(string: urlString) { webViewModel.reloadTile(url) }
        case .sitemap:
            sitemapResetID = UUID()
        case .notifications, .browser:
            break
        }
    }

    // MARK: - Navigation command handling

    private func handleNavigationCommand(_ command: NavigationCommand) {
        switch command {
        case let .switchToWebView(path):
            if let path, path.starts(with: "/") {
                showMainUI(path: path)
            } else {
                if !isMainUIShown { showMainUI(path: nil) }
                if let path { webViewModel.navigateCommand(path) }
            }
        case let .switchToSitemap(name, _):
            switchContent(to: .sitemap(name))
        }
        notificationService.navigationCommand = nil
    }

    // MARK: - Helpers

    private func setupExitToApp() {
        webViewModel.onExitToApp = {
            menuPresented = true
        }
    }

    private func switchToTile(_ urlString: String) {
        guard !urlString.isEmpty else { return }
        let resolvedUrl: URL?
        if urlString.hasPrefix("http") {
            resolvedUrl = URL(string: urlString)
        } else {
            guard let rootUrl = MainActorNetworkTracker.shared.activeConnection?.configuration.url else { return }
            resolvedUrl = Endpoint.resource(openHABRootUrl: rootUrl, path: urlString.prepare()).url
        }
        if let resolvedUrl {
            switchContent(to: .tile(resolvedUrl.absoluteString))
        }
    }

    private func openSafari(url: URL) {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        let svc = SFSafariViewController(url: url, configuration: config)
        UIApplication.shared.firstKeyWindow?.rootViewController?.present(svc, animated: true)
    }
}

// MARK: - Connecting placeholder

/// Shown centered over the (transparent) web view while a home is first loading. While the
/// tracker is still trying, the openHAB mark gently breathes above a spinner. Once an attempt
/// has failed it switches to a warning: a countdown to the next retry, or — when the tracker
/// has given up — a static "cannot connect" message. On an adaptive background so the blank
/// page reads as intentional in both light and dark mode.
private struct ConnectingPlaceholder: View {
    @ObservedObject private var networkTracker = MainActorNetworkTracker.shared

    private enum Phase: Equatable {
        case connecting
        case retrying(Date)
        case failed
        case noNetwork
    }

    private var phase: Phase {
        if !networkTracker.isNetworkAvailable {
            return .noNetwork
        }
        if let retry = networkTracker.nextRetryDate, retry.timeIntervalSinceNow > 0 {
            return .retrying(retry)
        }
        if networkTracker.status == .stopped {
            return .failed
        }
        return .connecting
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                switch phase {
                case .connecting:
                    PulsingLogo()
                    label(spinner: true) { Text("Connecting…") }
                case let .retrying(date):
                    statusIcon(.exclamationmarkTriangle)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, Int(date.timeIntervalSince(context.date).rounded(.up)))
                        label(spinner: false) { Text("Cannot connect — retrying in \(remaining)s") }
                    }
                case .failed:
                    statusIcon(.exclamationmarkTriangle)
                    label(spinner: false) { Text("Cannot connect to the server") }
                case .noNetwork:
                    statusIcon(.wifiSlash)
                    label(spinner: false) { Text("No network connection") }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: phase)
        }
    }

    private func statusIcon(_ symbol: SFSymbol) -> some View {
        Image(systemSymbol: symbol)
            .font(.system(size: 52))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
    }

    private func label(spinner: Bool, @ViewBuilder text: () -> some View) -> some View {
        HStack(spacing: 8) {
            if spinner {
                ProgressView().controlSize(.small)
            }
            text()
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

/// The openHAB mark breathing (opacity + scale). Extracted so that each time the connecting
/// phase reappears a fresh instance restarts the repeating animation from its `onAppear`.
private struct PulsingLogo: View {
    @State private var animating = false

    var body: some View {
        Image("openHABIcon")
            .resizable()
            .scaledToFit()
            .frame(width: 72, height: 72)
            .opacity(animating ? 1.0 : 0.55)
            .scaleEffect(animating ? 1.0 : 0.94)
            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: animating)
            .onAppear { animating = true }
    }
}

// MARK: - In-app toast banner

/// Slide-up banner driven by ToastService.
/// Layout mirrors sitemap input rows: text content on the left, action control
/// on the right (single action → plain button label; multiple → Menu with chevron).
private struct InAppToastBanner: View {
    let service: ToastService

    var body: some View {
        Group {
            if service.isPresented {
                HStack(alignment: .center, spacing: 12) {
                    // Left: title + message, takes all available space
                    VStack(alignment: .leading, spacing: 4) {
                        if !service.title.isEmpty {
                            Text(service.title)
                                .font(.headline)
                                .lineLimit(2)
                        }
                        if !service.message.isEmpty {
                            Text(service.message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Right: action control — only when actions are present
                    if !service.actions.isEmpty {
                        Divider()
                        actionControl
                    }
                }
                // fixedSize prevents Divider from expanding to the overlay's proposed screen height
                .fixedSize(horizontal: false, vertical: true)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding([.horizontal, .bottom])
                .contentShape(RoundedRectangle(cornerRadius: 12))
                .onTapGesture { dismiss() }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: service.showCount) { await autoDismiss() }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: service.isPresented)
    }

    @ViewBuilder
    private var actionControl: some View {
        if service.actions.count == 1, let item = service.actions.first {
            Button {
                fireAction(item)
            } label: {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 120)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
        } else {
            Menu {
                ForEach(service.actions, id: \.action) { item in
                    Button(item.title) { fireAction(item) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Actions")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .frame(maxWidth: 120)
                .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
        }
    }

    private func fireAction(_ item: NotificationActionItem) {
        service.onAction?(item)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            service.isPresented = false
        }
    }

    private func dismiss() {
        service.onTap?()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            service.isPresented = false
        }
    }

    private func autoDismiss() async {
        try? await Task.sleep(for: .seconds(5))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            service.isPresented = false
        }
    }
}
