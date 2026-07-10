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
    @State private var toastService = ToastService.shared
    @State private var menuPresented = false
    @State private var currentContent: TargetController = .webview
    @State private var currentViewTitle: String = ""
    @State private var activeNetworkConnection: ConnectionInfo? = MainActorNetworkTracker.shared.activeConnection
    @State private var showNotifications = false
    @State private var isDemoMode = false
    @State private var sitemapResetID = UUID()

    var body: some View {
        ZStack {
            contentView

            // Toolbar menu overlay
            ToolbarMenu(
                isPresented: $menuPresented,
                menuData: menuData,
                onSelect: { target in handleMenuSelection(target) },
                onReload: { webViewModel.reloadView() }
            )
        }
        .onAppear {
            ImageDownloader.default.authenticationChallengeResponder = networkService
            isDemoMode = Preferences.shared.currentHomePreferences.demomode
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
            webViewModel.clearView()
            menuData.clearAll()
            currentContent = .webview
            switchToSavedView()
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
            InAppToastBanner(service: toastService)
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
        #if DEBUG
        .onAppear {
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
                    return WebNavbarItem(label: label, jsAction: action, iconBase64: nil)
                }
                webViewModel.lockUITestContent()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    webViewModel.updateNavbarItems(items)
                }
            }
        }
        #endif
    }

    // MARK: - Content switching

    @ViewBuilder
    private var contentView: some View {
        switch currentContent {
        case .webview:
            ZStack(alignment: .top) {
                OpenHABWebViewContainer(viewModel: webViewModel)
                    .padding(.top, 44)
                    .background(.clear)
                menuBar
            }
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
            if case .webview = currentContent { return true }
            return false
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
                    ForEach(webViewModel.navbarItems) { item in
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
                        .ohMinimumHitTarget()
                        .accessibilityLabel(item.label)
                        .accessibilityIdentifier("NavbarProxyButton-\(item.label)")
                    }
                } else if isWebviewMode, activeNetworkConnection == nil {
                    HStack(spacing: 4) {
                        Image(systemSymbol: .wifiExclamationmark)
                        Text("Offline")
                            .ohTextToken(.secondary)
                        Button { webViewModel.reloadView() } label: {
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
                    .ohMinimumHitTarget()
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
                    .ohMinimumHitTarget()
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

    private func switchToSavedView() {
        if Preferences.shared.currentHomePreferences.demomode {
            switchContent(to: .sitemap("demo"))
        } else {
            let defaultView = Preferences.shared.currentHomePreferences.defaultView
            let defaultSitemap = Preferences.shared.currentHomePreferences.defaultSitemap
            if defaultView == "sitemap" {
                switchContent(to: .sitemap(defaultSitemap))
            } else {
                switchContent(to: .webview)
            }
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
            currentViewTitle = ""
            switchContent(to: .webview)
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

    // MARK: - Navigation command handling

    private func handleNavigationCommand(_ command: NavigationCommand) {
        switch command {
        case let .switchToWebView(path):
            if currentContent != .webview {
                switchContent(to: .webview)
            }
            if let path {
                if path.starts(with: "/") {
                    webViewModel.loadWebView(force: true, path: path)
                } else {
                    webViewModel.navigateCommand(path)
                }
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
        if urlString.hasPrefix("http") || urlString.hasPrefix("https") {
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
                .task { await autoDismiss() }
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
