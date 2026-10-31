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
import SFSafeSymbols
import SwiftUI

// MARK: - Connecting placeholder

/// Shown centered over the (transparent) web view while a home is first loading. While the
/// tracker is still trying, the openHAB mark gently breathes above a spinner. Once an attempt
/// has failed it switches to a warning: a countdown to the next retry, or — when the tracker
/// has given up — a static "cannot connect" message. On an adaptive background so the blank
/// page reads as intentional in both light and dark mode.
struct ConnectingPlaceholder: View {
    private enum Phase: Equatable {
        case connecting
        case retrying(Date)
        case failed
        case noNetwork
    }

    var networkTracker = MainActorNetworkTracker.shared

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
                    leadingIcon

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
                // .thickMaterial (rather than .regularMaterial) plus a tinted border and a
                // real drop shadow so the banner reads as its own floating surface against
                // busy content behind it (a MainUI page or a Sitemap's own rows) instead of
                // blending into whatever's already using translucency there.
                .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.tint.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                .padding([.horizontal, .bottom])
                .contentShape(RoundedRectangle(cornerRadius: 16))
                .onTapGesture { dismiss() }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: service.showCount) { await autoDismiss() }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: service.isPresented)
    }

    /// The item's own icon when available; otherwise a bell badge, so the banner always
    /// carries a "this is a notification" marker instead of just floating text that can
    /// be mistaken for part of the page behind it.
    @ViewBuilder
    private var leadingIcon: some View {
        if let iconURL = service.iconURL, let connection = service.connection {
            KFImage(iconURL)
                .withOpenHABCredentials(for: connection)
                .placeholder { bellBadge }
                .resizable()
                .frame(width: 32, height: 32)
                .clipShape(.rect(cornerRadius: 8))
        } else {
            bellBadge
        }
    }

    private var bellBadge: some View {
        Image(systemSymbol: .bellFill)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(.tint, in: .circle)
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
                    Image(systemSymbol: .chevronUpChevronDown)
                        .font(.caption2.weight(.semibold))
                }
                .frame(maxWidth: 120)
                .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
        }
    }

    /// Scales with content length so a longer message isn't cut off mid-read by the same
    /// flat timeout as a one-line alert. ~15 chars/second is a brisk-but-readable pace;
    /// clamped to [5, 10]s so a short toast still lingers and a long one doesn't sit forever.
    private var autoDismissDuration: Double {
        let charCount = service.title.count + service.message.count
        return (3.0 + Double(charCount) / 15.0).clamped(to: 5.0 ... 10.0)
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
        try? await Task.sleep(for: .seconds(autoDismissDuration))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            service.isPresented = false
        }
    }
}

// MARK: - Root view

struct OpenHABRootView: View {
    @StateObject private var networkService = NetworkConnectionService()
    @Environment(NotificationActionService.self) private var notificationService
    @Environment(\.scenePhase) private var scenePhase
    @State private var crashService = CrashReportService()
    @State private var menuData = MenuDataService()
    @State private var barVisibility = BarVisibility(revealDuration: BarVisibility.launchRevealDuration)

    #if DEBUG
    @State private var uiTestRevealScheduled = false
    #endif

    @StateObject private var webViewModel = OpenHABWebViewModel()
    @State private var currentContent: TargetController = .webview
    @State private var currentViewTitle = ""
    @State private var activeNetworkConnection: ConnectionInfo? = MainActorNetworkTracker.shared.activeConnection
    @State private var showNotifications = false
    @State private var sitemapResetID = UUID()
    @State private var cachedHomePrefs: HomePreferences?
    /// What was showing when the user started signing in, for the way back if they cancel.
    @State private var contentBeforeLogin: TargetController?

    var body: some View {
        ZStack(alignment: .bottom) {
            contentView
                .environment(\.appMenu, appMenuConfiguration)
            // A sibling above the content rather than an overlay of the navigation container.
            InAppToastBanner(service: ToastService.shared)
        }
        .environment(\.barVisibility, barVisibility)
        .statusBarHidden(barVisibility.isHidden)
        // Enabled while the setting hides the bars, so holding three fingers always shows them,
        // except under Guided Access.
        .background(ThreeFingerHoldInstaller(isEnabled: barVisibility.allowsReveal) { barVisibility.reveal() })
        .task { await loadBarSetting() }
        .task { await followGuidedAccess() }
        // The switch in the iOS Settings app may have changed while the app was in the background.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await loadBarSetting() }
        }
        .onChange(of: barsAreNeeded, initial: true) { _, needed in barVisibility.needsBars = needed }
        // swiftformat:disable indent
        #if DEBUG
        // UI tests cannot hold three fingers, so this does what the gesture does a while after the bars
        // have been hidden for good. Not at once: they are hidden for a moment before the page needs them.
        .task(id: barVisibility.isHidden) {
            guard barVisibility.isHidden, !uiTestRevealScheduled,
                  let delay = ProcessInfo.processInfo.environment["UITestRevealBarsAfter"].flatMap(Double.init) else { return }
            try? await Task.sleep(for: .seconds(1 + delay))
            guard !Task.isCancelled else { return }
            uiTestRevealScheduled = true
            barVisibility.reveal()
        }
        #endif
        // swiftformat:enable indent
        .onAppear {
            webViewModel.onLoginCancelled = { route in finishCancelledLogin(route: route) }
            #if DEBUG
            let env = ProcessInfo.processInfo.environment
            if env["UITest"] != nil {
                Task {
                    await Preferences.shared.modifyActiveHome { @Sendable prefs in prefs.demomode = true }
                }
            }
            if let title = env["UITestToastTitle"],
               let message = env["UITestToastMessage"] {
                let actions: [NotificationActionItem] = if let actionsJSON = env["UITestToastActions"],
                                                           let data = actionsJSON.data(using: .utf8),
                                                           let items = try? JSONDecoder().decode([NotificationActionItem].self, from: data) {
                    items
                } else {
                    []
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
                        Task { await webViewModel.loadHTMLString(html) }
                    }
                }
            }
            if let json = env["UITestWebViewNavbarItems"],
               let data = json.data(using: .utf8),
               let raw = try? JSONDecoder().decode([[String: String]].self, from: data) {
                let actions = raw.compactMap { dict -> OHBridgeNavbarAction? in
                    guard let label = dict["label"] else { return nil }
                    return OHBridgeNavbarAction(id: dict["id"] ?? label, label: label, icon: nil, disabled: nil)
                }
                webViewModel.lockUITestContent()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    webViewModel.setUITestNavbar(OHBridgeNavbarState(
                        title: "", titleInContent: false, hidden: false, back: nil, leading: actions, trailing: []
                    ))
                }
            }
            if env["UITestWebAuth"] == "pending" {
                webViewModel.setUITestAuthPending()
            } else if let json = env["UITestWebAuth"],
                      let auth = try? JSONDecoder().decode(OHBridgeAuthState.self, from: Data(json.utf8)) {
                webViewModel.setUITestAuth(auth)
            }
            if let json = env["UITestServer"],
               let server = UITestServerFixture(json: json) {
                menuData.injectForUITest(server: server.server, pages: server.menuPages, sitemaps: server.menuSitemaps)
            }
            #endif
            ImageDownloader.default.authenticationChallengeResponder = networkService
            notificationService.onPendingWebViewNavigation = { [weak weakWebViewModel = webViewModel] in
                weakWebViewModel?.markPendingExplicitNavigation()
            }
            Task { await switchToSavedView() }
        }
        // `initial: true` also delivers a command published before this view appeared,
        // as the `@Published` subscription used to. `handleNavigationCommand` resets the
        // command to nil, so the same command arriving again is still a change.
        .onChange(of: notificationService.navigationCommand, initial: true) { _, command in
            guard let command else { return }
            handleNavigationCommand(command)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("org.openhab.preferences.saved"))) { _ in
            Task { await loadBarSetting() }
            menuData.clearAndReload()
            webViewModel.reloadView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .homeDidSwitch)) { _ in
            menuData.clearForHomeSwitch()
            // Reset synchronously with the menu clear so a stale currentContent from the
            // previous home can't coincidentally match a same-named row once the new
            // home's sitemaps/pages arrive, before switchToSavedView() corrects it below.
            currentContent = .webview
            Task { await switchToSavedView() }
            // Reconcile the web view with the new home: loads if the active connection
            // already belongs to it (e.g. between two demo homes), otherwise blanks and
            // waits for the tracker to connect the new home.
            webViewModel.syncActiveConnection()
        }
        .task {
            var previousConnection: ConnectionInfo?
            for await state in await NetworkTracker.shared.stateStream() {
                guard state.activeConnection != previousConnection else { continue }
                previousConnection = state.activeConnection
                activeNetworkConnection = state.activeConnection
            }
        }
        .task {
            for await prefs in await Preferences.shared.currentHomePreferencesStream {
                cachedHomePrefs = prefs
            }
        }
        .sheet(isPresented: $showNotifications) {
            NavigationView { NotificationsView() }
        }
        .alert(
            networkService.certificateAlert?.title ?? "",
            isPresented: Binding(
                get: { networkService.certificateAlert != nil },
                // Defer to the next run loop tick: SwiftUI invokes this setter synchronously
                // while dismissing the alert, and mutating the @Published property inline
                // triggers "Publishing changes from within view updates is not allowed."
                set: {
                    if !$0 {
                        DispatchQueue.main.async { networkService.certificateAlert = nil }
                    }
                }
            )
        ) {
            Button("Always") { networkService.certificateAlertAction(.permitAlways) }
            Button("Once") { networkService.certificateAlertAction(.permitOnce) }
            Button("Deny", role: .cancel) { networkService.certificateAlertAction(.deny) }
        } message: {
            Text(networkService.certificateAlert?.message ?? "")
        }
        .task { await crashService.checkForPreviousCrash() }
        .alert("Crash Report", isPresented: $crashService.crashReportAlert) {
            Button("Send") { crashService.enableCrashReporting() }
            Button("Don't Send", role: .cancel) { crashService.deleteCrashReports() }
        } message: {
            Text("The app crashed during the previous session. Would you like to send a crash report?")
        }
        // SwiftFormat miscomputes indentation for a closure wrapped in #if/#endif with --ifdef no-indent.
        // swiftformat:disable indent
        #if DEBUG
        .overlay {
            ForEach(Array(webViewModel.uiTestReports.keys.sorted()), id: \.self) { key in
                Text(webViewModel.uiTestReports[key] ?? "")
                    .accessibilityIdentifier("UITestReport-\(key)")
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .allowsHitTesting(false)
            }
            Text(String(webViewModel.navbar.actions.count))
                .accessibilityIdentifier("UITestReport-navbarItemCount")
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
            Text(uiTestRevealScheduled ? "yes" : "no")
                .accessibilityIdentifier("UITestReport-barsRevealed")
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
            Text(barVisibility.isHidden ? "hidden" : "shown")
                .accessibilityIdentifier("UITestReport-barsHidden")
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
        }
        #endif
        // swiftformat:enable indent
    }
}

// MARK: - Content switching

private extension OpenHABRootView {
    @ViewBuilder
    var contentView: some View {
        switch currentContent {
        case .webview, .mainUIPage:
            nativeBarContent(tileTitle: nil)
        case let .sitemap(name, navigationState: state):
            SitemapNavigationView(sitemapName: name, navigationPath: state.navigationPath)
                .id("\(name)-\(state.navigationPath.last?.pageLink ?? "")-\(sitemapResetID)")
        case .tile:
            nativeBarContent(tileTitle: currentViewTitle)
        case .notifications, .browser:
            preconditionFailure("Modal/transient targets must never become currentContent")
        }
    }

    /// Hidden bars stay shown while the screen has nothing but an error or a spinner, since
    /// the indicator for it is in the bar.
    var barsAreNeeded: Bool {
        guard activeNetworkConnection != nil else { return true }
        switch currentContent {
        case .webview, .mainUIPage: return !webViewModel.hasLoadedContent
        default: return false
        }
    }

    /// What the app menu shows, for every screen with a navigation bar. See `AppMenu.swift`.
    var appMenuConfiguration: AppMenuConfiguration {
        AppMenuConfiguration(
            menuData: menuData,
            authStatus: webViewModel.authStatus,
            currentContent: currentContent,
            onSelect: { target in handleMenuSelection(target) },
            onReload: { reloadCurrentContent() }
        )
    }

    /// Main UI or a tile with a system navigation bar. See `MainUINavigationView`.
    func nativeBarContent(tileTitle: String?) -> some View {
        MainUINavigationView(
            webViewModel: webViewModel,
            activeConnection: activeNetworkConnection,
            tileTitle: tileTitle
        ) { reloadCurrentContent() }
    }

    /// The "Hide Status Bar" setting, which hides the navigation bar as well. See `BarVisibility`.
    func loadBarSetting() async {
        var hides = await HideBarsSystemSetting.sync()
        #if DEBUG
        if ProcessInfo.processInfo.environment["UITestHideBars"] != nil {
            hides = true
        }
        #endif
        barVisibility.hidesBars = hides
    }

    /// Guided Access hides the bars as well, see `BarVisibility`.
    func followGuidedAccess() async {
        barVisibility.isInGuidedAccess = BarVisibility.isGuidedAccessEnabled
        let changes = NotificationCenter.default.notifications(named: UIAccessibility.guidedAccessStatusDidChangeNotification)
        for await _ in changes {
            barVisibility.isInGuidedAccess = BarVisibility.isGuidedAccessEnabled
        }
    }

    func switchToSavedView() async {
        // Select the surface for the current home. Demo homes follow their defaultView like
        // any other home. The web view's actual load is driven by syncActiveConnection, so
        // here we only choose which content is shown.
        let prefs = await Preferences.shared.currentHomePreferences
        if prefs.defaultView == "sitemap" {
            switchContent(to: .sitemap(prefs.defaultSitemap))
        } else if !prefs.defaultMainUIPath.isEmpty {
            currentContent = .mainUIPage(prefs.defaultMainUIPath)
        } else {
            currentContent = .webview
        }
    }

    func switchContent(to newContent: TargetController) {
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
            let wasShowingTile = switch currentContent {
            case .tile: true
            default: false
            }

            currentContent = newContent

            switch newContent {
            case .webview:
                if wasShowingTile {
                    webViewModel.reloadView()
                }
            case .sitemap:
                break
            case let .tile(url):
                if let url = URL(string: url) {
                    webViewModel.loadTilePage(url)
                }
            default:
                break // modal/transient targets never reach switchContent
            }

            if !(cachedHomePrefs?.demomode ?? false) {
                let viewName: String
                switch newContent {
                case .webview: viewName = "web"
                case .sitemap: viewName = "sitemap"
                case .tile: viewName = "web" // treat tile as web for persistence
                default: return // modal/transient targets never reach switchContent
                }
                let capturedViewName = viewName
                Task {
                    await Preferences.shared.modifyActiveHome { @Sendable prefs in prefs.defaultView = capturedViewName }
                }
            }
        }
    }
}

// MARK: - Menu handling

private extension OpenHABRootView {
    var isMainUIShown: Bool {
        switch currentContent {
        case .webview, .mainUIPage: true
        default: false
        }
    }

    func handleMenuSelection(_ target: TargetController) {
        // Signing in starts from the profile; any other choice leaves a sign-in behind.
        if target == .mainUIPage(MainUIMenu.profileRoute), currentContent != target {
            contentBeforeLogin = currentContent
        } else {
            contentBeforeLogin = nil
        }
        switch target {
        case .webview:
            showMainUI(path: nil)
        case let .mainUIPage(path):
            // Only a page is worth landing on next time; Settings and the like are one-off visits.
            showMainUI(path: path, persistAsDefault: path.hasPrefix("/page/"))
        case let .sitemap(name, _):
            let capturedName = name
            Task {
                await Preferences.shared.modifyActiveHome { @Sendable prefs in prefs.defaultSitemap = capturedName }
            }
            switchContent(to: .sitemap(name))
        case .notifications:
            showNotifications = true
        case let .tile(urlString):
            currentViewTitle = menuData.label(forURL: urlString)
            switchToTile(urlString)
        case let .browser(urlString):
            if let url = URL(string: urlString) {
                SafariPresenter.present(url, entersReaderIfAvailable: true)
            }
        }
    }

    /// The user cancelled the sign-in on openHAB's authorize page: back to what they were looking
    /// at, with Main UI behind it at the route it was on.
    func finishCancelledLogin(route: String) {
        let wayBack = MainUILogin.wayBack(from: contentBeforeLogin, route: route)
        contentBeforeLogin = nil
        switch wayBack {
        case let .sitemap(content, mainUIRoute):
            currentContent = content
            webViewModel.loadWebView(force: false, path: mainUIRoute)
        case let .tile(url):
            currentContent = .tile(url)
            if let url = URL(string: url) {
                webViewModel.loadTilePage(url)
            }
        case let .mainUI(path):
            showMainUI(path: path, persistAsDefault: false)
        }
    }

    /// Shows the MainUI web surface at `path` (nil = the MainUI root). When the SPA is
    /// already live it routes client-side through the page's own Framework7 router, so
    /// no full page load happens and in-app state is preserved; otherwise it loads the
    /// URL at that path and Framework7 routes to it on startup. The chosen destination
    /// is recorded as `currentContent` so a later reload returns here rather than to an
    /// arbitrary route the user reached inside the SPA.
    ///
    /// - Parameter persistAsDefault: Whether `path` should be remembered as the home's
    ///   default landing page/tab. True when the user explicitly picked this destination
    ///   from the menu; false for a one-off notification-driven `ui:navigate:/page/…`
    ///   (openhab-ios#1336's follow-up: a notification tap was silently overwriting the
    ///   user's "standard path" setting, which then made a *different*, unrelated app
    ///   version look like it had fixed notification routing when it had merely inherited
    ///   the hijacked default).
    func showMainUI(path: String?, persistAsDefault: Bool = true) {
        let wasShowingMainUI = isMainUIShown
        // Ask the web view what it holds, not which surface was last visible: a tile's URL
        // survives a detour through a sitemap.
        let showsTile = webViewModel.isShowingTile
        Logger.notificationNavigation.info("showMainUI: path=\(path ?? "nil", privacy: .public) wasShowingMainUI=\(wasShowingMainUI) showsTile=\(showsTile) hasLoadedContent=\(webViewModel.hasLoadedContent) persistAsDefault=\(persistAsDefault)")

        currentContent = path.map(TargetController.mainUIPage) ?? .webview

        if showsTile {
            // Explicit path, so the origin-only ETag check can't skip the load.
            webViewModel.loadWebView(force: false, path: path ?? "/")
        } else if let path {
            routeMainUI(to: path)
        } else if !webViewModel.hasLoadedContent {
            webViewModel.loadWebView(force: false, path: nil)
        } else if wasShowingMainUI {
            // Picking Main UI while already on it goes to the root, like re-picking a sitemap.
            routeMainUI(to: "/")
        }
        // Coming back from a sitemap: the web view still holds the page, so leave it alone.

        guard persistAsDefault else { return }
        persistDefaultViewIfNeeded("web")
        if !(cachedHomePrefs?.demomode ?? false) {
            let capturedPath = path ?? ""
            Task {
                await Preferences.shared.modifyActiveHome { @Sendable prefs in prefs.defaultMainUIPath = capturedPath }
            }
        }
    }

    /// Routes client-side when the SPA is live, so its in-app state survives. `isMainUIReady`
    /// alone is not enough — it is true for `about:blank` too.
    func routeMainUI(to path: String) {
        if webViewModel.isMainUIReady, webViewModel.hasLoadedContent {
            Logger.notificationNavigation.info("routeMainUI: SPA already live — routing client-side to \(path, privacy: .public)")
            webViewModel.clearPendingExplicitNavigation()
            webViewModel.bridge.navigate(to: path)
        } else {
            Logger.notificationNavigation.info("routeMainUI: SPA not live yet — loading \(path, privacy: .public) directly")
            webViewModel.loadWebView(force: false, path: path)
        }
    }

    func persistDefaultViewIfNeeded(_ viewName: String) {
        guard !(cachedHomePrefs?.demomode ?? false) else { return }
        guard cachedHomePrefs?.defaultView != viewName else { return }
        let capturedViewName = viewName
        Task {
            await Preferences.shared.modifyActiveHome { @Sendable prefs in prefs.defaultView = capturedViewName }
        }
    }

    /// Reloads the destination currently selected in the menu — never the arbitrary
    /// route the user may have reached inside the SPA — so a reload always lands
    /// somewhere the menu can navigate away from.
    func reloadCurrentContent() {
        switch currentContent {
        case .webview:
            webViewModel.loadWebView(force: true, path: nil)
        case let .mainUIPage(path):
            webViewModel.loadWebView(force: true, path: path)
        case let .tile(urlString):
            if let url = URL(string: urlString) {
                webViewModel.reloadTile(url)
            }
        case .sitemap:
            sitemapResetID = UUID()
        case .notifications, .browser:
            break
        }
    }
}

// MARK: - Navigation command handling

private extension OpenHABRootView {
    func handleNavigationCommand(_ command: NavigationCommand) {
        let resolvedAction = NavigationCommandCoordinator.action(for: command, isMainUIShown: isMainUIShown)
        Logger.notificationNavigation.info("handleNavigationCommand: command=\(String(describing: command), privacy: .public) isMainUIShown=\(isMainUIShown) -> \(String(describing: resolvedAction), privacy: .public)")
        switch resolvedAction {
        case let .showMainUI(path):
            // Covers both an explicit server-side path and a "navigate:/page/…" command
            // from a notification's onClickAction (e.g. "ui:navigate:/page/my_page" — see
            // the openHAB Cloud Connector docs). Routing it through showMainUI rather than
            // the live-command fallback below matters when Main UI isn't already showing —
            // the common case for a notification tap — where that fallback shows the
            // MainUI root first and queues the command to run once the SPA reports
            // SSE-connected, which does not reliably happen before the user is looking at
            // the (wrong) root page. showMainUI instead loads straight to the target path
            // when the SPA isn't live yet, and routes client-side when it already is.
            // Not persisted as the default: this is a one-off notification deep link, not
            // the user picking a new home page (openhab-ios#1336).
            showMainUI(path: path, persistAsDefault: false)
        case .none:
            break
        case let .navigateLive(command, ensureShown):
            if ensureShown {
                showMainUI(path: nil, persistAsDefault: false)
            }
            if !webViewModel.bridge.run(command) {
                Logger.notificationNavigation.info("handleNavigationCommand: no Main UI message for \(command, privacy: .public)")
            }
        case let .switchToSitemap(name, widgetId):
            let capturedName = name
            let capturedWidgetId = widgetId
            Task { @MainActor in
                await Preferences.shared.modifyActiveHome { @Sendable prefs in prefs.defaultSitemap = capturedName }
                switchContent(to: .sitemap(capturedName, navigationState: .loading))
                let path = await resolveAncestorChain(sitemapName: capturedName, pageId: capturedWidgetId)
                currentContent = .sitemap(capturedName, navigationState: .ready(path))
            }
        }
        notificationService.navigationCommand = nil
    }

    @MainActor
    func resolveAncestorChain(sitemapName: String, pageId: String?) async -> [LinkedPageNavigation] {
        guard let pageId, !pageId.isEmpty else { return [] }
        let connection: ConnectionInfo
        if let active = MainActorNetworkTracker.shared.activeConnection {
            connection = active
        } else if let active = await NetworkTracker.shared.waitForActiveConnection() {
            connection = active
        } else {
            return []
        }
        guard let service = try? OpenAPIService(
            connectionConfiguration: connection.configuration,
            serviceConfiguration: .shortTerm
        ) else { return [] }
        return await (try? service.ancestorChain(sitemapname: sitemapName, pageId: pageId))?
            .map { LinkedPageNavigation(pageLink: $0.link, pageTitle: $0.title) } ?? []
    }
}

// MARK: - Helpers

private extension OpenHABRootView {
    func switchToTile(_ urlString: String) {
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
}
