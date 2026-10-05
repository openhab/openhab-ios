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
@testable import openHAB
import Testing
import WebKit

@Suite("OHBridge")
@MainActor
struct OHBridgeTests {
    /// Feeds `json` to a bridge and returns what it reported.
    private func events(for json: String) -> [OHBridgeEvent] {
        let host = OHBridgeHost()
        var seen: [OHBridgeEvent] = []
        host.onEvent = { seen.append($0) }
        host.receive(json: json)
        return seen
    }

    // MARK: - Web → host

    @Test("Reads ui.hello")
    func readsHello() {
        let json = #"{"v":1,"type":"ui.hello","payload":{"protocol":1,"impl":"shim","accepted":["navbar","menu"],"features":["navbar","menu","routeRestore","layout"]}}"#
        guard case let .hello(hello)? = events(for: json).first else {
            Issue.record("expected a hello")
            return
        }
        #expect(hello.impl == .shim)
        #expect(hello.accepted == ["navbar", "menu"])
    }

    @Test("Reads navbar.state with its back button and actions")
    func readsNavbarState() {
        let json = #"""
        {"v":1,"type":"navbar.state","payload":{"title":"Kitchen","titleInContent":false,"hidden":false,
         "back":{"label":"Overview"},
         "leading":[],
         "trailing":[{"id":"3-1","label":"Edit","icon":{"name":"f7:pencil"}},{"id":"3-2","label":"Save"}]}}
        """#
        guard case let .navbarState(state)? = events(for: json).first else {
            Issue.record("expected a navbar state")
            return
        }
        #expect(state.title == "Kitchen")
        #expect(state.back?.label == "Overview")
        #expect(state.actions.map(\.id) == ["3-1", "3-2"])
        #expect(state.actions.first?.icon?.name == "f7:pencil")
    }

    @Test("Reads menu.state with submenus")
    func readsMenuState() {
        let json = #"""
        {"v":1,"type":"menu.state","payload":{"sections":[
          {"id":"pages","items":[{"id":"/page/kitchen","label":"Kitchen","path":"/page/kitchen","active":true}]},
          {"id":"settings","title":"Administration","items":[
            {"id":"/settings/","label":"Settings","path":"/settings/","icon":{"name":"f7:gear_alt_fill","md":"material:settings"},
             "children":[{"id":"/settings/things/","label":"Things","path":"/settings/things/"}],
             "more":[{"id":"/settings/transformations/","label":"Transformations","path":"/settings/transformations/"}]}]},
          {"id":"account","items":[{"id":"unlock","label":"Unlock Administration","icon":{"svg":"<svg></svg>"}}]}]}}
        """#
        guard case let .menuState(menu)? = events(for: json).first else {
            Issue.record("expected a menu state")
            return
        }
        #expect(menu.sections.map(\.id) == ["pages", "settings", "account"])
        #expect(menu.sections[0].items.first?.active == true)
        let settings = menu.sections[1].items[0]
        #expect(menu.sections[1].title == "Administration")
        #expect(settings.icon?.md == "material:settings")
        #expect(settings.children?.map(\.label) == ["Things"])
        #expect(settings.more?.map(\.label) == ["Transformations"])
        let unlock = menu.sections[2].items[0]
        #expect(unlock.path == nil)
        #expect(unlock.icon?.svg == "<svg></svg>")
    }

    @Test("Reads nav.changed with props")
    func readsNavChanged() {
        let json = #"{"v":1,"type":"nav.changed","payload":{"path":"/page/a","history":["/","/page/a"],"props":["{}","{\"deep\":true}"],"modal":false}}"#
        guard case let .navChanged(state)? = events(for: json).first else {
            Issue.record("expected a nav state")
            return
        }
        #expect(state.history == ["/", "/page/a"])
        #expect(state.props?.last == #"{"deep":true}"#)
    }

    @Test("Reads connection.state")
    func readsConnectionState() {
        let json = #"{"v":1,"type":"connection.state","payload":{"sseConnected":true}}"#
        guard case let .connectionState(connected)? = events(for: json).first else {
            Issue.record("expected a connection state")
            return
        }
        #expect(connected)
    }

    @Test("Ignores unknown types and unreadable messages")
    func ignoresUnknown() {
        #expect(events(for: #"{"v":1,"type":"something.new","payload":{}}"#).isEmpty)
        #expect(events(for: "not json").isEmpty)
        #expect(events(for: #"{"v":1,"type":"navbar.state","payload":{"title":1}}"#).isEmpty)
    }

    // MARK: - Host → web

    @Test("Reads Main UI's handleCommand strings")
    func readsCommands() {
        #expect(OHBridgeCommand("navigate:/page/kitchen") == .navigate("/page/kitchen"))
        #expect(OHBridgeCommand("popup:widget:garage_door") == .openModal(.popup, target: "widget:garage_door"))
        #expect(OHBridgeCommand("sheet:page:energy") == .openModal(.sheet, target: "page:energy"))
        #expect(OHBridgeCommand("close") == .closeModals)
        #expect(OHBridgeCommand(" back ") == .back)
        #expect(OHBridgeCommand("reload") == .reload)
    }

    @Test("Commands with no bridge message are refused", arguments: [
        "notification:hello", "navigate:", "popup:", "dance", ""
    ])
    func refusesUnknownCommands(command: String) {
        #expect(OHBridgeCommand(command) == nil)
        #expect(!OHBridgeHost().run(command))
    }

    @Test("Installs OHBridge with the host's info, then the shim")
    func installsScripts() {
        let controller = WKUserContentController()
        OHBridgeHost().installScripts(
            on: controller,
            restore: ["/", "/page/a"],
            props: nil,
            basePath: "/cloud",
            layout: OHBridgeLayout(insets: .init(top: 59, bottom: 34), navbarHeight: 44)
        )
        let sources = controller.userScripts.map(\.source)
        #expect(sources.count == 2)
        let bootstrap = sources.first ?? ""
        #expect(bootstrap.contains(#""initialHistory":["/","/page/a"]"#))
        #expect(bootstrap.contains(#""features":["navbar","menu","routeRestore"]"#))
        #expect(bootstrap.contains(#""platform":"ios""#))
        #expect(bootstrap.contains(#"basePath: "/cloud""#))
        #expect(bootstrap.contains("webkit.messageHandlers.OHBridge"))
        #expect(sources.last == OHBridgeHost.shimScript)
    }

    @Test("The shim ships in the app bundle")
    func shimIsBundled() {
        #expect(OHBridgeHost.shimScript.contains("OHBridge shim"))
    }

    // MARK: - Origin

    @Test("Only the connection's own origin can talk to the bridge", arguments: [
        ("https://oh.example.com", "https", "oh.example.com", 0, true),
        ("https://oh.example.com", "https", "OH.example.com", 443, true),
        ("http://openhab.local:8080", "http", "openhab.local", 8080, true),
        ("http://openhab.local:8080", "http", "openhab.local", 0, false),
        ("https://oh.example.com", "http", "oh.example.com", 0, false),
        ("https://oh.example.com", "https", "grafana.example.com", 0, false),
        ("https://oh.example.com", "https", "oh.example.com.evil.com", 0, false)
    ])
    func sameOrigin(url: String, scheme: String, host: String, port: Int, expected: Bool) throws {
        let connection = try #require(URL(string: url))
        #expect(OHBridge.isSameOrigin(connection, scheme: scheme, host: host, port: port) == expected)
    }

    @Test("Trusts where the app's own load was redirected, not where a page went by itself")
    func trustsRedirectOfAppLoad() throws {
        let host = OHBridgeHost()
        let connection = try #require(URL(string: "http://openhab.local:8080"))
        host.connectionURLs = { [connection] }
        // WebKit's own navigations: a bare WKNavigation() crashes when released.
        let webView = WKWebView()
        let appLoad = webView.loadHTMLString("", baseURL: nil)
        let pageLoad = webView.loadHTMLString("", baseURL: nil)
        host.appDidStartLoad(appLoad)
        #expect(!host.acceptsOrigin(scheme: "https", host: "openhab.local", port: 0))

        host.pageDidCommit(appLoad, url: URL(string: "https://openhab.local/"))
        #expect(host.acceptsOrigin(scheme: "https", host: "openhab.local", port: 0))
        #expect(host.acceptsOrigin(scheme: "http", host: "openhab.local", port: 8080))

        host.pageDidCommit(pageLoad, url: URL(string: "https://evil.example/"))
        #expect(!host.acceptsOrigin(scheme: "https", host: "evil.example", port: 0))
        #expect(host.acceptsOrigin(scheme: "https", host: "openhab.local", port: 0))
    }

    // MARK: - Shim

    @Test("Sidebar entries without a path keep their ids when Main UI renders the panel again")
    func shimMenuIDs() async throws {
        let page = ShimPage()
        page.load(ShimPage.sidebarHTML)
        let json = try await page.waitFor("JSON.stringify((__posted.filter(function (m) { return m.type === 'menu.state' }).pop() || {}).payload || null)")
        let menu = try JSONDecoder().decode(OHBridgeMenuState.self, from: Data(json.utf8))
        #expect(menu.sections.flatMap(\.items).map(\.id) == ["m:Tools/Reload", "m:Tools/Help", "m:Tools/Help:2", "/settings/"])

        // A fresh render: same entries, new elements, no tags.
        _ = try await page.run("""
        var c = document.querySelector('.panel-left .page-content');
        c.innerHTML = c.innerHTML.replace(/ data-oh-menu="[^"]*"/g, ''); ''
        """)
        let clicked = try await page.run("""
        OHBridge.onmessage({ data: JSON.stringify({ v: 1, type: 'menu.activate', id: 't1', payload: { id: 'm:Tools/Help:2' } }) });
        window.__clicked || ''
        """)
        #expect(clicked == "Help (second)")
        let reply = try await page.run("JSON.stringify(__posted.filter(function (m) { return m.replyTo === 't1' }).map(function (m) { return m.payload.ok }))")
        #expect(reply == "[true]")
    }

    // MARK: - Icons

    @Test("The bundled Framework7 font knows its icon names")
    func f7Font() {
        #expect(F7IconFont.fontName != nil)
        #expect(F7IconFont.hasIcon("gear_alt_fill"))
        #expect(F7IconFont.hasIcon("house"))
        #expect(!F7IconFont.hasIcon("not_a_real_icon"))
    }

    @Test("Icons the font doesn't draw load from the server or Iconify")
    func imageURLs() {
        let root = "http://openhab.local:8080"
        #expect(OHBridgeIconView.imageURL(for: "oh:classic:light", rootURL: root)?.absoluteString.hasPrefix("\(root)/icon/light") == true)
        #expect(OHBridgeIconView.imageURL(for: "material:settings", rootURL: root)?.host == "api.iconify.design")
    }
}

/// A web view running the shim against a stand-in for the host's `OHBridge`, which records what
/// the shim posts in `__posted`.
@MainActor
private final class ShimPage {
    static let sidebarHTML = """
    <!DOCTYPE html><html><body>
    <div id="app" class="framework7-root">
      <div class="panel panel-left"><div class="page"><div class="page-content">
        <div class="block-title">Tools</div>
        <div class="list"><ul>
          <li><a href="#" class="item-link" onclick="window.__clicked = 'Reload'"><div class="item-inner"><div class="item-title">Reload</div></div></a></li>
          <li><a href="#" class="item-link" onclick="window.__clicked = 'Help'"><div class="item-inner"><div class="item-title">Help</div></div></a></li>
          <li><a href="#" class="item-link" onclick="window.__clicked = 'Help (second)'"><div class="item-inner"><div class="item-title">Help</div></div></a></li>
          <li><a href="/settings/" class="item-link"><div class="item-inner"><div class="item-title">Settings</div></div></a></li>
        </ul></div>
      </div></div></div>
      <div class="view view-main"><div class="page page-current"><div class="navbar"></div><div class="page-content"></div></div></div>
    </div>
    </body></html>
    """

    private static let stubBridge = """
    window.__posted = [];
    window.OHBridge = {
        info: { features: ['navbar', 'menu'] },
        onmessage: null,
        postMessage: function (json) { window.__posted.push(JSON.parse(json)) }
    };
    """

    let webView: WKWebView

    init() {
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: Self.stubBridge, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        controller.addUserScript(WKUserScript(source: OHBridgeHost.shimScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: configuration)
    }

    func load(_ html: String) {
        webView.loadHTMLString(html, baseURL: URL(string: "https://openhab.example/"))
    }

    /// Runs `js`, whose last expression must be a string.
    func run(_ js: String) async throws -> String {
        try await webView.evaluateJavaScript(js) as? String ?? ""
    }

    /// Runs `js` until it gives something other than "null".
    func waitFor(_ js: String) async throws -> String {
        for _ in 0 ..< 50 {
            let result = try? await run(js)
            if let result, !result.isEmpty, result != "null" { return result }
            try await Task.sleep(for: .milliseconds(100))
        }
        Issue.record("timed out waiting for \(js)")
        return "null"
    }
}
