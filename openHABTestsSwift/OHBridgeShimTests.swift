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
          <li><a href="#" class="item-link"><div class="item-inner"><div class="item-title">Help:2</div></div></a></li>
          <li><a href="/settings/" class="item-link"><div class="item-inner"><div class="item-title">Settings</div></div></a></li>
        </ul></div>
      </div></div></div>
      <div class="view view-main"><div class="page page-current"><div class="navbar"></div><div class="page-content"></div></div></div>
    </div>
    </body></html>
    """

    static let navbarHTML = """
    <!DOCTYPE html><html><body>
    <div id="app" class="framework7-root">
      <div class="view view-main"><div class="page page-current">
        <div class="navbar"><div class="navbar-inner">
          <div class="title">Logs</div>
          <div class="right">
            <a class="link icon-only"><i class="icon f7-icons">square_list</i></a>
            <a class="link"><i class="icon f7-icons">checkmark</i> Save</a>
          </div>
        </div></div>
        <div class="page-content"></div>
      </div></div>
    </div>
    </body></html>
    """

    /// A page made with `hideNavbar`: Main UI renders no navbar for it.
    static let noNavbarHTML = """
    <!DOCTYPE html><html><body>
    <div id="app" class="framework7-root">
      <div class="view view-main"><div class="page page-current"><div class="page-content"><p>Kiosk</p></div></div></div>
    </div>
    </body></html>
    """

    /// Framework7's router as far as the shim uses it. `/` only redirects. Closing a modal and going
    /// back are recorded in `__closed` and `__back`.
    static let fakeRouter = """
    (function () {
      function closer(kind) {
        return { close: function (el) { el.classList.remove('modal-in'); (window.__closed = window.__closed || []).push(kind) } }
      }
      document.querySelector('.view-main').f7View = { router: {
        history: ['/', '/overview/'],
        propsHistory: [],
        findMatchingRoute: function (url) {
          return url === '/' ? { route: { path: '/', redirect: '/overview/' } } : { route: { path: url } }
        },
        back: function () { window.__back = true },
        app: { popup: closer('popup'), sheet: closer('sheet'), popover: closer('popover'),
               actions: closer('actions'), dialog: closer('dialog'), card: closer('card') }
      } }
      return ''
    })()
    """

    let webView: WKWebView

    /// `host` runs before the bridge, like the app's own scripts.
    init(info: String = "{ features: ['navbar', 'menu'] }", host: String = "") {
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: host + Self.stubBridge(info: info), injectionTime: .atDocumentStart, forMainFrameOnly: true))
        controller.addUserScript(WKUserScript(source: OHBridgeHost.shimScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: configuration)
    }

    /// A stand-in for the host's `OHBridge`, with `info` as a JavaScript object literal.
    private static func stubBridge(info: String) -> String {
        """
        window.__posted = [];
        window.OHBridge = {
            info: \(info),
            onmessage: null,
            postMessage: function (json) { window.__posted.push(JSON.parse(json)) }
        };
        """
    }

    func load(_ html: String, at address: String = "https://openhab.example/") {
        webView.loadHTMLString(html, baseURL: URL(string: address))
    }

    /// Sends a command as the app would, and returns the shim's reply as JSON.
    func command(_ type: String, id: String) async throws -> String {
        _ = try await run("OHBridge.onmessage({ data: JSON.stringify({ v: 1, type: '\(type)', id: '\(id)', payload: {} }) }); ''")
        return try await waitFor("JSON.stringify((__posted.filter(function (m) { return m.replyTo === '\(id)' }).pop() || {}).payload || null)")
    }

    /// Runs `js`, whose last expression must be a string.
    func run(_ js: String) async throws -> String {
        try await webView.evaluateJavaScript(js) as? String ?? ""
    }

    /// Runs `js` until it gives something other than "null".
    func waitFor(_ js: String) async throws -> String {
        for _ in 0 ..< 50 {
            let result = try? await run(js)
            if let result, !result.isEmpty, result != "null" {
                return result
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        Issue.record("timed out waiting for \(js)")
        return "null"
    }
}

@Suite("OHBridge shim")
@MainActor
struct OHBridgeShimTests {
    @Test("Sidebar entries without a path keep their ids when Main UI renders the panel again")
    func shimMenuIDs() async throws {
        let page = ShimPage()
        page.load(ShimPage.sidebarHTML)
        let json = try await page.waitFor("JSON.stringify((__posted.filter(function (m) { return m.type === 'menu.state' }).pop() || {}).payload || null)")
        let menu = try JSONDecoder().decode(OHBridgeMenuState.self, from: Data(json.utf8))
        #expect(menu.sections.flatMap(\.items).map(\.id) == ["m:Tools/Reload", "m:Tools/Help", "m:Tools/Help:2", "m:Tools/Help:2:2", "/settings/"])

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

    @Test("An element Main UI reuses for an entry with a path loses its old tag")
    func shimDropsStaleMenuTags() async throws {
        let page = ShimPage()
        page.load(ShimPage.sidebarHTML)
        _ = try await page.waitFor("JSON.stringify((__posted.filter(function (m) { return m.type === 'menu.state' }).pop() || {}).payload || null)")

        // Reload keeps its element, and its old tag, but now goes to a page.
        let clicked = try await page.run("""
        document.querySelector('[data-oh-menu="m:Tools/Reload"]').setAttribute('href', '/reload/');
        window.__clicked = '';
        OHBridge.onmessage({ data: JSON.stringify({ v: 1, type: 'menu.activate', id: 't2', payload: { id: 'm:Tools/Reload' } }) });
        window.__clicked || ''
        """)
        #expect(clicked.isEmpty)
        let reply = try await page.run("JSON.stringify(__posted.filter(function (m) { return m.replyTo === 't2' }).map(function (m) { return m.payload.error && m.payload.error.code }))")
        #expect(reply == #"["not_found"]"#)
    }

    @Test("An icon-only navbar button is sent without a label, a button with text keeps it")
    func shimNavbarLabels() async throws {
        let page = ShimPage()
        page.load(ShimPage.navbarHTML)
        let json = try await page.waitFor("JSON.stringify((__posted.filter(function (m) { return m.type === 'navbar.state' }).pop() || {}).payload || null)")
        let navbar = try JSONDecoder().decode(OHBridgeNavbarState.self, from: Data(json.utf8))
        #expect(navbar.trailing.map(\.label) == ["", "Save"])
        #expect(navbar.trailing.first?.icon?.name == "f7:square_list")
    }

    private func latestAuth(of page: ShimPage) async throws -> OHBridgeAuthState {
        let json = try await page.waitFor("JSON.stringify((__posted.filter(function (m) { return m.type === 'auth.state' }).pop() || {}).payload || null)")
        return try JSONDecoder().decode(OHBridgeAuthState.self, from: Data(json.utf8))
    }

    @Test("Reports the user from Main UI's user store")
    func shimAuthFromUserStore() async throws {
        let page = ShimPage(info: "{ features: ['auth'] }")
        page.load(ShimPage.sidebarHTML.replacingOccurrences(of: "</body>", with: """
        <script>document.getElementById('app').__vue_app__ = { config: { globalProperties: { $pinia: { state: { value: {
          user: { user: { name: 'ann', roles: ['user'] }, noAuth: false } } } } } } }</script></body>
        """))
        let auth = try await latestAuth(of: page)
        #expect(auth.user == OHBridgeUser(name: "ann", roles: ["user"]))
        #expect(auth.noAuth == false)
    }

    @Test("Reports nobody signed in from the user store")
    func shimAuthSignedOut() async throws {
        let page = ShimPage(info: "{ features: ['auth'] }")
        page.load(ShimPage.sidebarHTML.replacingOccurrences(of: "</body>", with: """
        <script>document.getElementById('app').__vue_app__ = { config: { globalProperties: { $pinia: { state: { value: {
          user: { user: null, noAuth: false } } } } } } }</script></body>
        """))
        let auth = try await latestAuth(of: page)
        #expect(auth.user == nil)
    }

    @Test("Without a user store, reads the user from the sidebar and takes the Settings entry for an administrator")
    func shimAuthFromSidebar() async throws {
        let page = ShimPage(info: "{ features: ['auth'] }")
        page.load(ShimPage.sidebarHTML.replacingOccurrences(
            of: #"<div class="page"><div class="page-content">"#,
            with: #"<div class="page"><div class="account"><div class="list"><ul><li><a href="/profile/"><div class="item-title">ann</div></a></li></ul></div></div><div class="page-content">"#
        ))
        let auth = try await latestAuth(of: page)
        #expect(auth.user == OHBridgeUser(name: "ann", roles: ["administrator"]))
    }

    @Test("Without a user store, a sign-in button in the sidebar means nobody is signed in")
    func shimAuthSidebarLocked() async throws {
        let page = ShimPage(info: "{ features: ['auth'] }")
        page.load(ShimPage.sidebarHTML.replacingOccurrences(
            of: #"<div class="page"><div class="page-content">"#,
            with: #"<div class="page"><div class="account"><a class="button">Unlock</a></div><div class="page-content">"#
        ))
        let auth = try await latestAuth(of: page)
        #expect(auth.user == nil)
    }

    /// Main UI's login comes back to the front page with the code in the address.
    @Test("Restoring pages leaves an address with a query alone")
    func shimKeepsLoginQuery() async throws {
        let page = ShimPage(info: "{ features: ['routeRestore'], initialHistory: ['/', '/page/kitchen'] }")
        page.load(ShimPage.sidebarHTML, at: "https://openhab.example/?code=abc&state=xyz")
        let address = try await page.waitFor("document.getElementById('app') ? location.pathname + location.search : 'null'")
        #expect(address == "/?code=abc&state=xyz")
    }

    @Test("Restoring pages on the bare front page moves to the last one")
    func shimRestoresOnFrontPage() async throws {
        let page = ShimPage(info: "{ features: ['routeRestore'], initialHistory: ['/', '/page/kitchen'] }")
        page.load(ShimPage.sidebarHTML)
        let address = try await page.waitFor("document.getElementById('app') ? location.pathname + location.search : 'null'")
        #expect(address == "/page/kitchen")
    }

    @Test("A page made without a navbar says so, one with a navbar does not")
    func shimReportsPageWithoutNavbar() async throws {
        let withoutNavbar = ShimPage()
        withoutNavbar.load(ShimPage.noNavbarHTML)
        let json = try await withoutNavbar.waitFor("JSON.stringify((__posted.filter(function (m) { return m.type === 'navbar.state' }).pop() || {}).payload || null)")
        #expect(try JSONDecoder().decode(OHBridgeNavbarState.self, from: Data(json.utf8)).noNavbar == true)

        let withNavbar = ShimPage()
        withNavbar.load(ShimPage.navbarHTML)
        let other = try await withNavbar.waitFor("JSON.stringify((__posted.filter(function (m) { return m.type === 'navbar.state' }).pop() || {}).payload || null)")
        #expect(try JSONDecoder().decode(OHBridgeNavbarState.self, from: Data(other.utf8)).noNavbar == nil)
    }

    @Test("A bar above the web view leaves no room on pages, and the app shows the title")
    func shimBarOutside() async throws {
        let page = ShimPage(info: "{ features: ['navbar'], layout: { insets: { top: 0, bottom: 0 }, navbarHeight: 0 } }")
        page.load(ShimPage.navbarHTML.replacingOccurrences(of: #"class="navbar""#, with: #"class="navbar navbar-large""#))
        let json = try await page.waitFor("JSON.stringify((__posted.filter(function (m) { return m.type === 'navbar.state' }).pop() || {}).payload || null)")
        let navbar = try JSONDecoder().decode(OHBridgeNavbarState.self, from: Data(json.utf8))
        #expect(!navbar.titleInContent)
        let height = try await page.run("getComputedStyle(document.querySelector('.view-main')).getPropertyValue('--f7-navbar-height').trim()")
        #expect(height == "0px")
    }

    @Test("Keeps the app's own goFullscreen unless the app draws the bar", arguments: [
        ("[]", "app"), ("['navbar']", "none")
    ])
    func shimGoFullscreen(features: String, expected: String) async throws {
        let page = ShimPage(
            info: "{ features: \(features) }",
            host: "window.OHApp = { goFullscreen: function () { window.__full = 'app' } };"
        )
        page.load(ShimPage.navbarHTML)
        _ = try await page.waitFor("window.__posted && document.getElementById('app') ? 'done' : 'null'")
        let result = try await page.run("OHApp.goFullscreen(); window.__full || 'none'")
        #expect(result == expected)
    }

    @Test("Leaves out the exit button on the md theme too")
    func shimSkipsMdExitButton() async throws {
        let page = ShimPage()
        page.load(ShimPage.navbarHTML.replacingOccurrences(
            of: "</div>\n        </div></div>",
            with: #"<a class="link"><i class="icon material-icons">exit_to_app</i></a></div>\n        </div></div>"#
        ))
        let json = try await page.waitFor("JSON.stringify((__posted.filter(function (m) { return m.type === 'navbar.state' }).pop() || {}).payload || null)")
        let navbar = try JSONDecoder().decode(OHBridgeNavbarState.self, from: Data(json.utf8))
        #expect(navbar.trailing.count == 2)
        #expect(navbar.trailing.allSatisfy { $0.icon?.name != "material:exit_to_app" })
    }

    @Test("Leaves redirects out of the history, and counts a dialog as open on top")
    func shimHistoryAndModals() async throws {
        let page = ShimPage()
        page.load(ShimPage.navbarHTML)
        _ = try await page.waitFor("__posted.some(function (m) { return m.type === 'ui.hello' }) ? 'done' : 'null'")
        _ = try await page.run(ShimPage.fakeRouter)

        let state = try await page.command("nav.getState", id: "g1")
        #expect(state.contains(#""history":["/overview/"]"#))
        #expect(state.contains(#""modal":false"#))

        _ = try await page.run("document.body.insertAdjacentHTML('beforeend', '<div class=\"dialog modal-in\"></div>'); ''")
        #expect(try await page.command("nav.getState", id: "g2").contains(#""modal":true"#))

        _ = try await page.command("nav.back", id: "b1")
        let closed = try await page.run("JSON.stringify({ closed: window.__closed || [], back: !!window.__back })")
        #expect(closed == #"{"closed":["dialog"],"back":false}"#, "Back closes the dialog instead of going back")
    }

    @Test("Closing modals closes a popup opened by an address too")
    func shimClosesModals() async throws {
        let page = ShimPage()
        page.load(ShimPage.navbarHTML)
        _ = try await page.waitFor("__posted.some(function (m) { return m.type === 'ui.hello' }) ? 'done' : 'null'")
        _ = try await page.run(ShimPage.fakeRouter)
        _ = try await page.run("document.body.insertAdjacentHTML('beforeend', '<div class=\"popup modal-in\"></div><div class=\"sheet-modal modal-in\"></div>'); ''")

        let reply = try await page.command("nav.closeModals", id: "c1")
        #expect(reply.contains(#""ok":true"#))
        let closed = try await page.run("JSON.stringify(window.__closed || [])")
        #expect(closed == #"["popup","sheet"]"#)
    }

    @Test("An open popup keeps its own bar and moves the app's out of the way")
    func shimHidesBarForPopup() async throws {
        let page = ShimPage()
        page.load(ShimPage.sidebarHTML.replacingOccurrences(
            of: "</body>",
            with: #"<div class="popup modal-in"><div class="navbar"><div class="navbar-inner"><div class="title">Pick</div></div></div></div></body>"#
        ))
        let hidden = try await page.waitFor("""
        var s = (__posted.filter(function (m) { return m.type === 'navbar.state' }).pop() || {}).payload;
        s && s.hidden ? 'yes' : 'null'
        """)
        #expect(hidden == "yes")
        let proxied = try await page.run("document.querySelector('.popup .navbar').classList.contains('oh-navbar-proxied') ? 'yes' : 'no'")
        #expect(proxied == "no")
    }

    @Test("The shim stays quiet when Main UI speaks the bridge itself")
    func shimStandsDownForMainUI() async throws {
        let page = ShimPage()
        page.load(ShimPage.sidebarHTML.replacingOccurrences(
            of: "<body>",
            with: "<body><script>OHBridge.onmessage = function () {}</script>"
        ))
        // The blank document a new web view starts with is already complete, so wait for this page:
        // the stub bridge's `__posted` and Main UI's `#app`. By then the shim has decided to stand down.
        _ = try await page.waitFor("window.__posted && document.getElementById('app') && document.readyState === 'complete' ? 'done' : 'null'")
        try await Task.sleep(for: .milliseconds(500))
        let sent = try await page.run("JSON.stringify(__posted.map(function (m) { return m.type }))")
        #expect(sent == "[]")
    }
}
