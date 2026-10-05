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

import Foundation
import OpenHABCore
import os.log
import WebKit

/// What the page told us.
enum OHBridgeEvent {
    case hello(OHBridgeHello)
    case connectionState(sseConnected: Bool)
    case navChanged(OHBridgeNavState)
    case navbarState(OHBridgeNavbarState)
    case menuState(OHBridgeMenuState)
}

/// The host end of the bridge to Main UI: installs it in a web view, checks and decodes what the
/// page posts, and tells the page what to do. Everything about the protocol lives here; callers
/// see Swift methods and `OHBridgeEvent`s. Delivery follows docs/mainui-bridge: messages wait for
/// the page's `ui.hello`, then retry until it replies.
@MainActor
final class OHBridgeHost {
    private final class Pending {
        let type: String
        let json: String
        let queuedAt = Date()
        var attemptsLeft = OHBridgeHost.maxAttempts
        var timer: Task<Void, Never>?

        init(type: String, json: String) {
            self.type = type
            self.json = json
        }
    }

    /// No reply within this long means the page wasn't listening yet.
    nonisolated static let acknowledgementTimeout: Duration = .milliseconds(750)
    nonisolated static let retryDelay: Duration = .milliseconds(300)
    nonisolated static let maxAttempts = 6
    /// A message still waiting for a page this long after it was sent is dropped, so a command
    /// from a notification can't fire long after the user has moved on.
    nonisolated static let maxWait: TimeInterval = 30

    /// What the host offers to take over from Main UI.
    nonisolated static let features = ["navbar", "menu", "routeRestore"]

    nonisolated static let shimScript: String = {
        guard let url = Bundle.main.url(forResource: "oh-bridge-shim", withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            Logger.viewController.error("OHBridge: oh-bridge-shim.js is missing from the app bundle")
            return ""
        }
        return source
    }()

    weak var webView: WKWebView?
    var onEvent: ((OHBridgeEvent) -> Void)?
    /// Basic auth for a reverse proxy, answered to auth.getCredentials. Nil when there is none.
    var credentials: (() -> OHBridgeCredentials?)?
    /// Where the active connection serves Main UI. Only pages from these origins, or from where
    /// the server redirected a load the app started, are listened to.
    var connectionURLs: () -> [URL] = { [] }

    #if DEBUG
    /// UI test fixtures load as local HTML, which has no origin to check.
    var acceptsLocalPages = false
    #endif

    private var pending: [String: Pending] = [:]
    /// The last page load the app started itself, until it commits.
    private var appNavigation: WKNavigation?
    /// Where that load ended up, e.g. https after the server redirected http. A page that goes
    /// somewhere else by itself — a link, a script, a redirect of its own — isn't trusted this way.
    private var appLoadedURL: URL?
    private var nextID = 0
    /// What the page now loaded said it is in its `ui.hello`. Nil until then: messages wait.
    private var page: OHBridgeHello.Impl?
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        return encoder
    }()

    /// True once Main UI (or the shim for it) has said hello on the page now loaded, so it can be
    /// navigated in place.
    var isMainUIReady: Bool {
        page == .mainui || page == .shim
    }

    // MARK: - Setup

    /// Adds the bridge and the shim to the scripts every page in the web view starts with.
    ///
    /// - Parameters:
    ///   - restore: pages to put back as Main UI starts, oldest first, and the props each was
    ///     opened with. Nil to leave Main UI's own memory alone.
    ///   - basePath: what Main UI's addresses hang off, with no trailing slash.
    func installScripts(on controller: WKUserContentController,
                        restore: [String]?,
                        props: [String]?,
                        basePath: String,
                        layout: OHBridgeLayout) {
        let info = OHBridgeHostInfo(
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            features: Self.features,
            initialHistory: restore,
            initialProps: props,
            layout: layout
        )
        // The bridge object first, then the shim that speaks it for Main UI versions without it.
        controller.addUserScript(
            WKUserScript(source: bootstrapScript(info: info, basePath: basePath), injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
        controller.addUserScript(
            WKUserScript(source: Self.shimScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
    }

    /// Installs `window.OHBridge` before any page script runs. Shaped like Android's
    /// addWebMessageListener object, so the shim and Main UI see the same thing on both platforms.
    private func bootstrapScript(info: OHBridgeHostInfo, basePath: String) -> String {
        let infoJSON = (try? encoder.encode(info)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let basePathJSON = (try? encoder.encode(basePath)).flatMap { String(data: $0, encoding: .utf8) } ?? #""""#
        return """
        (function () {
            if (window.OHBridge) return;
            window.OHBridgeShimConfig = { basePath: \(basePathJSON) };
            window.OHBridge = {
                info: Object.freeze(\(infoJSON)),
                onmessage: null,
                postMessage: function (json) {
                    window.webkit.messageHandlers.\(OHBridge.messageHandlerName).postMessage(String(json));
                }
            };
        })();
        """
    }

    // MARK: - Web → host

    /// A message posted to the `OHBridge` handler. Ignored unless it comes from the main frame on
    /// the active connection's origin: anything else — a site the page went to, an iframe — could
    /// otherwise drive the app or ask it for the connection's credentials.
    func receive(_ message: WKScriptMessage) {
        guard let json = message.body as? String else { return }
        guard accepts(isMainFrame: message.frameInfo.isMainFrame, origin: message.frameInfo.securityOrigin) else {
            Logger.viewController.warning("OHBridge: ignored a message from another frame or origin")
            return
        }
        receive(json: json)
    }

    private func accepts(isMainFrame: Bool, origin: WKSecurityOrigin) -> Bool {
        guard isMainFrame else { return false }
        #if DEBUG
        if acceptsLocalPages, origin.host.isEmpty { return true }
        #endif
        return acceptsOrigin(scheme: origin.protocol, host: origin.host, port: origin.port)
    }

    /// The connection's own origins, and where the app's last load of Main UI ended up.
    func acceptsOrigin(scheme: String, host: String, port: Int) -> Bool {
        (connectionURLs() + [appLoadedURL].compactMap(\.self)).contains {
            OHBridge.isSameOrigin($0, scheme: scheme, host: host, port: port)
        }
    }

    /// Decodes a message the page posted. Origin checks are done by `receive(_:)`.
    func receive(json: String) {
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(OHBridgeHeader.self, from: data) else {
            Logger.viewController.error("OHBridge: unreadable message")
            return
        }
        do {
            switch header.type {
            case "reply":
                guard let replyTo = header.replyTo else { return }
                try handleReply(to: replyTo, decoder.decode(OHBridgeIncoming<OHBridgeReply>.self, from: data).payload)
            case "ui.hello":
                let hello = try decoder.decode(OHBridgeIncoming<OHBridgeHello>.self, from: data).payload
                onEvent?(.hello(hello))
                pageDidSayHello(hello.impl)
            case "connection.state":
                let state = try decoder.decode(OHBridgeIncoming<OHBridgeConnectionState>.self, from: data).payload
                onEvent?(.connectionState(sseConnected: state.sseConnected))
            case "nav.changed":
                try onEvent?(.navChanged(decoder.decode(OHBridgeIncoming<OHBridgeNavState>.self, from: data).payload))
            case "navbar.state":
                try onEvent?(.navbarState(decoder.decode(OHBridgeIncoming<OHBridgeNavbarState>.self, from: data).payload))
            case "menu.state":
                try onEvent?(.menuState(decoder.decode(OHBridgeIncoming<OHBridgeMenuState>.self, from: data).payload))
            case "auth.getCredentials":
                guard let id = header.id else { return }
                deliver(type: "reply", replyTo: id, payload: OHBridgeCredentialsReply(result: credentials?()))
            default:
                Logger.viewController.debug("OHBridge: ignoring \(header.type, privacy: .public)")
            }
        } catch {
            Logger.viewController.error("OHBridge: bad \(header.type, privacy: .public) payload: \(error.localizedDescription)")
        }
    }

    private func handleReply(to id: String, _ reply: OHBridgeReply) {
        guard let entry = pending[id] else { return }
        if reply.ok {
            finish(id)
        } else if reply.error?.code == OHBridgeReplyError.notReady {
            retry(id, entry)
        } else {
            Logger.viewController.info("OHBridge: \(entry.type, privacy: .public) refused: \(reply.error?.code ?? "?", privacy: .public)")
            finish(id)
        }
    }

    // MARK: - Host → web

    func navigate(to path: String) {
        send("nav.navigate", OHBridgeNavigate(path: path))
    }

    /// The host's back button.
    func back() {
        send("nav.back")
    }

    func openModal(_ kind: OHBridgeModalKind, target: String) {
        send("nav.openModal", OHBridgeOpenModal(kind: kind, target: target))
    }

    func closeModals() {
        send("nav.closeModals")
    }

    func reload() {
        send("ui.reload")
    }

    /// A button on the host's bar, mirrored from Main UI's navbar.
    func activateNavbarAction(_ id: String) {
        send("navbar.activate", OHBridgeActivate(id: id))
    }

    /// A sidebar entry without a path, e.g. "Unlock Administration".
    func activateMenuItem(_ id: String) {
        send("menu.activate", OHBridgeActivate(id: id))
    }

    /// The space the host's chrome covers changed.
    func updateLayout(_ layout: OHBridgeLayout) {
        send("layout.changed", layout)
    }

    /// Runs a router command in Main UI's old `handleCommand` string form. False when there is no
    /// bridge message for it.
    @discardableResult
    func run(_ command: String) -> Bool {
        guard let parsed = OHBridgeCommand(command) else { return false }
        switch parsed {
        case let .navigate(path): navigate(to: path)
        case let .openModal(kind, target): openModal(kind, target: target)
        case .closeModals: closeModals()
        case .back: back()
        case .reload: reload()
        }
        return true
    }

    /// Sends a message the page must acknowledge. A newer message of the same type replaces one
    /// still waiting or being retried.
    private func send(_ type: String, _ payload: some Encodable) {
        for (id, entry) in pending where entry.type == type {
            finish(id)
        }
        nextID += 1
        let id = "h\(nextID)"
        guard let data = try? encoder.encode(OHBridgeOutgoing(type: type, id: id, replyTo: nil, payload: payload)),
              let json = String(data: data, encoding: .utf8) else { return }
        let entry = Pending(type: type, json: json)
        pending[id] = entry
        attempt(id, entry)
    }

    private func send(_ type: String) {
        send(type, OHBridgeEmpty())
    }

    /// Call with a load of Main UI the app starts itself. Where it ends up after redirects is
    /// trusted like the connection's own origin.
    func trustRedirects(of navigation: WKNavigation?) {
        appNavigation = navigation
    }

    /// Call when a page commits. Remembers where the app's own load ended up.
    func recordCommit(_ navigation: WKNavigation?, url: URL?) {
        guard let navigation, navigation === appNavigation else { return }
        appNavigation = nil
        appLoadedURL = url
    }

    /// A new page is loading. Messages wait for its `ui.hello`, including any that were part way
    /// through their retries on the page that is going away.
    func pageWillLoad() {
        page = nil
        for entry in pending.values {
            entry.timer?.cancel()
            entry.attemptsLeft = Self.maxAttempts
        }
    }

    private func pageDidSayHello(_ impl: OHBridgeHello.Impl) {
        page = impl
        for (id, entry) in pending {
            attempt(id, entry)
        }
    }

    /// Main UI (or the shim) takes everything. A page that isn't Main UI only takes what makes
    /// sense on any page; navigation waits for the next page that is.
    private func pageTakes(_ type: String) -> Bool {
        switch page {
        case .mainui, .shim: true
        case .other: type == "layout.changed" || type == "ui.reload"
        case nil: false
        }
    }

    private func deliver(type: String, replyTo: String, payload: some Encodable) {
        guard let data = try? encoder.encode(OHBridgeOutgoing(type: type, id: nil, replyTo: replyTo, payload: payload)),
              let json = String(data: data, encoding: .utf8) else { return }
        evaluate(json) { _ in }
    }

    private func attempt(_ id: String, _ entry: Pending) {
        guard pending[id] === entry else { return }
        guard Date().timeIntervalSince(entry.queuedAt) < Self.maxWait else {
            Logger.viewController.warning("OHBridge: \(entry.type, privacy: .public) waited too long for a page, dropped")
            finish(id)
            return
        }
        // Waits for the next ui.hello, which calls this again.
        guard pageTakes(entry.type) else { return }
        guard entry.attemptsLeft > 0 else {
            Logger.viewController.warning("OHBridge: \(entry.type, privacy: .public) not acknowledged, giving up")
            finish(id)
            return
        }
        entry.attemptsLeft -= 1
        evaluate(entry.json) { [weak self] delivered in
            guard let self, pending[id] === entry else { return }
            if delivered {
                // Delivered but unanswered: the page took it before it could reply. Try again.
                schedule(id, entry, after: Self.acknowledgementTimeout)
            } else {
                retry(id, entry)
            }
        }
    }

    private func retry(_ id: String, _ entry: Pending) {
        schedule(id, entry, after: Self.retryDelay)
    }

    private func schedule(_ id: String, _ entry: Pending, after delay: Duration) {
        entry.timer?.cancel()
        entry.timer = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.attempt(id, entry)
        }
    }

    private func finish(_ id: String) {
        pending[id]?.timer?.cancel()
        pending[id] = nil
    }

    /// Hands `json` to the page's `OHBridge.onmessage`. False when nothing was listening.
    private func evaluate(_ json: String, completion: @escaping @MainActor (Bool) -> Void) {
        guard let webView,
              let literal = (try? encoder.encode(json)).flatMap({ String(data: $0, encoding: .utf8) }) else {
            completion(false)
            return
        }
        let script = """
        (function (m) {
            var b = window.OHBridge;
            if (!b || typeof b.onmessage !== 'function') return false;
            b.onmessage({ data: m });
            return true;
        })(\(literal))
        """
        webView.evaluateJavaScript(script) { result, _ in
            Task { @MainActor in completion(result as? Bool == true) }
        }
    }
}
