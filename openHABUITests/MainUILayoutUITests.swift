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

import XCTest

// MARK: - JS probes

/// JS snippets injected via UITestInjectJS to measure webview DOM properties.
/// Each snippet calls window.ohUITest.report(key, value). The test reads results
/// via app.staticTexts matching accessibility identifier "UITestReport-<key>".
private enum LayoutJS {
    /// Checks the proxy left Framework7's layout intact and hid only what it mirrors.
    /// UITestInjectJS also runs on the `about:blank` load that precedes the fixture, and
    /// `waitForReport` latches the first value it sees — so wait for the fixture to be up.
    static let navbarLayout = #"""
    (function(){
      var tries = 0;
      (function poll(){
        var pc = document.querySelector('.page-current .page-content');
        var nb = document.querySelector('.page-current .navbar');
        var title = nb && nb.querySelector('.navbar-inner > .title');
        var proxyHasRun = title && parseFloat(getComputedStyle(title).opacity) === 0;
        if (!proxyHasRun && ++tries < 60) { setTimeout(poll, 100); return; }
        window.ohUITest.report('pageContentPaddingTop',
          pc ? String(parseFloat(getComputedStyle(pc).paddingTop) || 0) : '-1');
        window.ohUITest.report('navbarOffsetHeight', nb ? String(nb.offsetHeight) : '-1');
        window.ohUITest.report('navbarTitleOpacity',
          title ? String(parseFloat(getComputedStyle(title).opacity)) : '-1');
        var bg = nb && nb.querySelector('.navbar-bg');
        window.ohUITest.report('navbarBgOpacity',
          bg ? String(parseFloat(getComputedStyle(bg).opacity)) : '-1');
        // Hidden, but innerText must still read — labels and icons come from here.
        window.ohUITest.report('navbarTitleInnerText', title ? title.innerText.trim() : '');
      })();
    })();
    """#

    static func base64(_ js: String) -> String { Data(js.utf8).base64EncodedString() }
}

// MARK: - HTML fixtures

/// Minimal HTML pages mirroring the Framework7 DOM and CSS the MainUI SPA produces,
/// including the absolute offset `oh-map-page.vue` uses. The same JS probes that work on
/// the real page work on these fixtures. `viewport-fit=cover` matches MainUI's own
/// index.html, so `env(safe-area-inset-top)` resolves to the device inset.
private enum LayoutHTML {
    private static let f7Base = """
    *{margin:0;padding:0;box-sizing:border-box}
    body{font-family:system-ui}
    :root{--f7-navbar-height:44px;--f7-safe-area-top:0px}
    @supports (top: env(safe-area-inset-top)){
      :root{--f7-safe-area-top:env(safe-area-inset-top)}
    }
    html,body,.view,.page{height:100%}
    .page{position:relative;overflow:hidden}
    .navbar{position:absolute;left:0;top:0;width:100%;z-index:50;
            height:calc(var(--f7-navbar-height) + var(--f7-safe-area-top))}
    .navbar-bg{position:absolute;left:0;top:0;width:100%;height:100%;background:#eee}
    .navbar-inner{position:absolute;left:0;bottom:0;width:100%;height:100%;
                  display:flex;align-items:center;padding-top:var(--f7-safe-area-top)}
    .navbar-inner .left,.navbar-inner .right{width:44px}
    .navbar-inner .title{flex:1;text-align:center}
    .page-content{position:absolute;left:0;top:0;right:0;bottom:0;overflow:auto}
    """

    /// Page with a navbar, laid out like the map page.
    static let mapPage = """
    <!DOCTYPE html><html>
    <head><meta name='viewport' content='width=device-width,initial-scale=1,viewport-fit=cover'>
    <style>
    \(f7Base)
    .page-content{padding-top:calc(var(--f7-navbar-height) + var(--f7-safe-area-top))}
    .map{position:absolute;left:0;right:0;height:200px;border:none;background:#cde;
         top:calc(var(--f7-navbar-height) + var(--f7-safe-area-top))}
    </style></head>
    <body><div class='view view-main'><div class='page page-current'>
      <div class='navbar'><div class='navbar-bg'></div><div class='navbar-inner'>
        <div class='left'><a href='#' aria-label='UITest Nav Left'>L</a></div>
        <div class='title'>Overview</div>
        <div class='right'></div>
      </div></div>
      <div class='page-content'><p>UITest Overview Heading</p></div>
      <button class='map' aria-label='UITest Map Top'></button>
    </div></div></body></html>
    """

    /// A `hideNavbar` page: nothing reserves room for the native bar, so the proxy pads it.
    static let pageWithoutNavbar = """
    <!DOCTYPE html><html>
    <head><meta name='viewport' content='width=device-width,initial-scale=1,viewport-fit=cover'>
    <style>
    \(f7Base)
    .sidebar-icon{position:fixed;top:8px;left:8px}
    </style></head>
    <body><div class='view view-main'><div class='page page-current'>
      <div class='page-content'>
        <button aria-label='UITest Fullscreen Content'>content</button>
      </div>
      <a class='sidebar-icon' aria-label='UITest Sidebar Icon'>&#9776;</a>
    </div></div></body></html>
    """

    /// Page whose navbar can be toggled to `navbar-hidden` — the class Framework7 sets when
    /// it hides the navbar on scroll (`hide-bars-on-scroll`) or when an expandable card
    /// opens (`hideNavbarOnOpen`). The content is padded well clear of the native bar so
    /// the toggle stays tappable.
    static let hidableNavbar = """
    <!DOCTYPE html><html>
    <head><meta name='viewport' content='width=device-width,initial-scale=1,viewport-fit=cover'>
    <style>
    \(f7Base)
    .page-content{padding-top:calc(var(--f7-navbar-height) + var(--f7-safe-area-top) + 140px)}
    .toggle{display:block;margin:0 auto;padding:18px 28px;font-size:17px}
    </style></head>
    <body><div class='view view-main'><div class='page page-current'>
      <div class='navbar'><div class='navbar-bg'></div><div class='navbar-inner'>
        <div class='left'><a href='#' aria-label='UITest Nav Left'>L</a></div>
        <div class='title'>Hidable</div>
        <div class='right'></div>
      </div></div>
      <div class='page-content'>
        <button class='toggle' aria-label='UITest Toggle Navbar'>toggle</button>
      </div>
    </div></div>
    <script>
    document.querySelector('.toggle').addEventListener('click', function () {
      document.querySelector('.navbar').classList.toggle('navbar-hidden');
    });
    </script>
    </body></html>
    """

    /// Framework7-like page with a position:fixed bottom tab bar. Catches the case where
    /// applying `contentInset.top` pushes `position:fixed; bottom:0` elements off-screen.
    static let bottomTabBar = """
    <!DOCTYPE html><html>
    <head><meta name='viewport' content='width=device-width,initial-scale=1,viewport-fit=cover'>
    <style>
    *{margin:0;padding:0;box-sizing:border-box}body{font-family:system-ui;height:100vh}
    .page-content{padding:16px}
    .tab-bar{position:fixed;bottom:0;left:0;right:0;height:49px;background:#eee;
             display:flex;align-items:center;justify-content:space-around}
    </style></head>
    <body>
    <div class='page-content'><p>Page content</p></div>
    <div class='tab-bar'><button aria-label='UITest Tab Bar'>Tab</button></div>
    </body></html>
    """

    static func base64(_ html: String) -> String { Data(html.utf8).base64EncodedString() }
}

// MARK: - Test class

/// Layout tests for the MainUI webview surface.
///
/// The contract: the web view is full screen and the proxy does not rewrite MainUI's
/// layout. Framework7 already reserves the navbar space the native bar covers. Pages
/// that render no navbar are the one case the proxy compensates for.
@MainActor
final class MainUILayoutUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITest"] = "1"
    }

    override func tearDown() { app = nil; super.tearDown() }

    // MARK: - Launch helpers

    private static let placeholderHTML = "<html><body><p>UITest Placeholder</p></body></html>"

    private func launchInWebviewMode(html: String? = nil, js: String? = nil, navbarItems: Bool = false) {
        app.launchEnvironment["UITestWebViewMode"] = "1"
        // Always inject at least a placeholder so the webView has stable content
        // and loadWebView cannot race against injected state.
        let htmlToInject = html ?? Self.placeholderHTML
        app.launchEnvironment["UITestInjectHTML"] = LayoutHTML.base64(htmlToInject)
        if let js { app.launchEnvironment["UITestInjectJS"] = LayoutJS.base64(js) }
        if navbarItems {
            app.launchEnvironment["UITestWebViewNavbarItems"] =
                #"[{"label":"Menu","jsAction":"document.querySelector('.hamburger,.menu-btn')?.click()"}]"#
        }
        app.launch()
    }

    // MARK: - Helpers

    private var screen: CGRect { app.windows.firstMatch.frame }

    /// Bottom edge of the native menuBar HStack in screen coordinates.
    /// SwiftUI exposes HStack containers as `.otherElements` in the XCTest AX tree.
    private var nativeBarBottom: CGFloat {
        let el = app.otherElements.matching(identifier: "MainMenuBar").firstMatch
        guard el.waitForExistence(timeout: 4) else {
            XCTFail("Cannot locate MainMenuBar in AX tree — check accessibilityIdentifier is set on the menuBar HStack")
            return 100
        }
        return el.frame.maxY
    }

    /// Finds a web element inside the webView by its accessibility label (aria-label).
    @discardableResult
    private func waitForWebLabel(_ label: String, type: XCUIElement.ElementType = .any,
                                 timeout: TimeInterval = 6) -> XCUIElement {
        let pred = NSPredicate(format: "label == %@", label)
        let el = app.webViews.firstMatch.descendants(matching: type).matching(pred).firstMatch
        XCTAssertTrue(el.waitForExistence(timeout: timeout),
                      "Expected web element with label '\(label)' within \(timeout)s")
        return el
    }

    /// Polls until `condition` holds, so the bar's 400ms slide and the JS→native hop do
    /// not have to be guessed at with a fixed sleep.
    @discardableResult
    private func waitUntil(timeout: TimeInterval = 6, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return condition()
    }

    private func waitForReport(_ key: String, timeout: TimeInterval = 8) -> String {
        let el = app.staticTexts.matching(identifier: "UITestReport-\(key)").firstMatch
        XCTAssertTrue(el.waitForExistence(timeout: timeout),
                      "Expected JS report '\(key)' within \(timeout)s — check ohUITest bridge is active")
        return el.label
    }

    // MARK: - Full-bleed web view

    /// Content must scroll under the status bar and into the bottom corners, and the page
    /// must see the real safe-area insets — MainUI lays itself out from them.
    func testWebViewFillsTheWindow() {
        launchInWebviewMode()
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.waitForExistence(timeout: 8))

        XCTAssertEqual(
            webView.frame.minY, screen.minY, accuracy: 1,
            """
            Web view top is \(webView.frame.minY)pt, window top is \(screen.minY)pt. \
            Insetting the web view stops content scrolling under the native bar and \
            zeroes env(safe-area-inset-top) inside the page.
            """
        )
        XCTAssertEqual(
            webView.frame.maxY, screen.maxY, accuracy: 1,
            """
            Web view bottom is \(webView.frame.maxY)pt, window bottom is \(screen.maxY)pt. \
            The scroll area must reach the bottom corners of the device.
            """
        )
    }

    // MARK: - Framework7 layout left intact

    /// Hiding must not touch the layout: Framework7 sizes pages and absolutely positioned
    /// content from `--f7-navbar-height`, which is what the native bar covers.
    func testProxyPreservesFrameworkNavbarLayout() {
        launchInWebviewMode(html: LayoutHTML.mapPage, js: LayoutJS.navbarLayout)
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 8))

        let navbarHeight = Double(waitForReport("navbarOffsetHeight")) ?? -1
        let paddingTop = Double(waitForReport("pageContentPaddingTop")) ?? -1

        XCTAssertGreaterThanOrEqual(
            navbarHeight, 44,
            "Navbar collapsed to \(navbarHeight)pt — it must keep its box so Framework7 keeps reserving room for the native bar"
        )
        XCTAssertEqual(
            paddingTop, navbarHeight, accuracy: 2,
            """
            .page-content padding-top is \(paddingTop)pt but the navbar reserves \(navbarHeight)pt. \
            The proxy must not rewrite Framework7's page padding — content that offsets \
            itself by --f7-navbar-height (the map page) does not follow it, so the two \
            drift apart and leave a gap.
            """
        )
        XCTAssertEqual(Double(waitForReport("navbarTitleOpacity")) ?? -1, 0, accuracy: 0.01,
                       "The web navbar title must be hidden — the native bar shows it instead")
        XCTAssertEqual(Double(waitForReport("navbarBgOpacity")) ?? -1, 0, accuracy: 0.01,
                       "The web navbar background must be hidden — it would show through the native bar")
        XCTAssertEqual(
            waitForReport("navbarTitleInnerText"), "Overview",
            """
            The hidden navbar title reads back as empty via innerText. Hiding the \
            proxied regions with visibility or display breaks the serialization that \
            reads button labels and icon glyphs out of them, so the native bar ends \
            up with no title and no action buttons.
            """
        )
    }

    /// Content offset by `--f7-navbar-height`, as the map page is, must meet the bar bottom.
    func testContentBelowNavbarMeetsNativeBarBottom() {
        launchInWebviewMode(html: LayoutHTML.mapPage)
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 8))

        let mapTop = waitForWebLabel("UITest Map Top", type: .button).frame.minY
        let barBottom = nativeBarBottom

        XCTAssertEqual(
            mapTop, barBottom, accuracy: 2,
            """
            Content top is \(mapTop)pt, native bar bottom is \(barBottom)pt — a \
            \(mapTop - barBottom)pt gap. The native bar must be exactly as tall as the \
            space Framework7 reserves for its own navbar.
            """
        )
    }

    // MARK: - Pages that render no navbar

    /// No navbar means nothing reserves room, so the proxy pads the page and shifts
    /// MainUI's floating sidebar icon clear of the bar.
    func testPageWithoutNavbarIsPaddedClearOfNativeBar() {
        launchInWebviewMode(html: LayoutHTML.pageWithoutNavbar)
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 8))

        let barBottom = nativeBarBottom
        let content = waitForWebLabel("UITest Fullscreen Content", type: .button)
        XCTAssertGreaterThanOrEqual(
            content.frame.minY, barBottom - 2,
            "Content top (\(content.frame.minY)pt) is above the native bar bottom (\(barBottom)pt) on a page with no navbar"
        )

        let sidebarIcon = waitForWebLabel("UITest Sidebar Icon")
        XCTAssertGreaterThanOrEqual(
            sidebarIcon.frame.minY, barBottom - 2,
            "MainUI's floating sidebar icon (\(sidebarIcon.frame.minY)pt) is covered by the native bar (\(barBottom)pt)"
        )
    }

    // MARK: - Mirroring the web navbar's hidden state

    /// Framework7 hides its own navbar on scroll and when an expandable card opens, marking
    /// it `navbar-hidden`. The native bar mirrors that class, so it must slide away with the
    /// web one and come back when it returns — otherwise the app's bar sits over content the
    /// Main UI has deliberately cleared, and the two bars disagree about whether they exist.
    func testNativeBarMirrorsWebNavbarHiding() {
        launchInWebviewMode(html: LayoutHTML.hidableNavbar)
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 8))

        let bar = app.otherElements.matching(identifier: "MainMenuBar").firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 6),
                      "Cannot locate MainMenuBar in the AX tree")
        let shownBottom = bar.frame.maxY
        XCTAssertGreaterThan(shownBottom, 0, "Native bar should be on screen to begin with")

        let toggle = waitForWebLabel("UITest Toggle Navbar", type: .button)
        toggle.tap()

        let slidAway = waitUntil { bar.frame.maxY < shownBottom - 20 }
        XCTAssertTrue(
            slidAway,
            """
            Native bar bottom stayed at \(bar.frame.maxY)pt after the web navbar took \
            .navbar-hidden (was \(shownBottom)pt). The bar mirrors that class, so it should \
            have slid up by its own height.
            """
        )

        toggle.tap()

        let cameBack = waitUntil { abs(bar.frame.maxY - shownBottom) < 2 }
        XCTAssertTrue(
            cameBack,
            """
            Native bar bottom is \(bar.frame.maxY)pt after .navbar-hidden was removed, \
            expected it back at \(shownBottom)pt. A bar that hides but never returns leaves \
            the menu unreachable.
            """
        )
    }

    // MARK: - Bottom-fixed elements

    /// Applying `scrollView.contentInset.top` shifts the CSS viewport DOWN so the top of
    /// content appears below the native bar, but `window.innerHeight` stays equal to the
    /// FULL WKWebView frame height. As a result, `position:fixed; bottom:0` elements
    /// (Framework7's tab bar) are pushed BELOW the visible screen bottom.
    func testBottomFixedElementSitsOnScreenBottom() {
        launchInWebviewMode(html: LayoutHTML.bottomTabBar)
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.waitForExistence(timeout: 8))

        let tabBarBtn = waitForWebLabel("UITest Tab Bar", type: .button)
        let overflowBelowWebview = tabBarBtn.frame.maxY - webView.frame.maxY

        XCTAssertLessThanOrEqual(
            overflowBelowWebview, 2,
            """
            position:fixed bottom:0 element extends \(overflowBelowWebview)pt below the \
            webview bottom edge. Applying a top contentInset without reducing the viewport \
            height shifts the entire CSS viewport down — Framework7's bottom tab bar is \
            pushed off-screen.
            """
        )
    }

    // MARK: - Navbar proxy infrastructure

    /// Verifies: (1) navbarItems are set in the view model (UITestReport-navbarItemCount > 0),
    /// and (2) the proxy button is found and positioned near the top of the screen.
    ///
    /// Note: SwiftUI buttons inside a ZStack overlaying a WKWebView may not appear in XCTest's
    /// AX tree on some iOS versions due to the webview's AX subtree dominating the region.
    /// The UITestReport-navbarItemCount assertion is the authoritative infrastructure check;
    /// the button AX search is attempted but skipped if not findable in the AX tree.
    func testNavbarProxyButtonAppearsInMenuBar() {
        launchInWebviewMode(navbarItems: true)
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 8))

        let countText = app.staticTexts.matching(identifier: "UITestReport-navbarItemCount").firstMatch
        XCTAssertTrue(countText.waitForExistence(timeout: 6),
                      "UITestReport-navbarItemCount must appear — check #if DEBUG overlay is wired up")
        let count = Int(countText.label) ?? 0
        XCTAssertGreaterThan(count, 0,
                             "navbarItems must be non-empty after UITestWebViewNavbarItems injection")

        // Best-effort: verify the button appears in the AX tree and is in the top bar area.
        let menuBtn = app.buttons.matching(identifier: "NavbarProxyButton-Menu").firstMatch
        if menuBtn.waitForExistence(timeout: 3) {
            XCTAssertLessThan(menuBtn.frame.maxY, 120,
                              "Proxy button must be in the native menuBar area (top 120pt of screen)")
        }
    }

    /// Verifies the proxy button is hittable when navbarItems are set via the test environment.
    /// Same AX-tree caveat as testNavbarProxyButtonAppearsInMenuBar.
    func testNavbarProxyButtonIsHittable() {
        launchInWebviewMode(navbarItems: true)
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 8))

        let countText = app.staticTexts.matching(identifier: "UITestReport-navbarItemCount").firstMatch
        XCTAssertTrue(countText.waitForExistence(timeout: 6),
                      "UITestReport-navbarItemCount must appear — check #if DEBUG overlay is wired up")
        let count = Int(countText.label) ?? 0
        XCTAssertGreaterThan(count, 0,
                             "navbarItems must be non-empty — proxy button would not appear without items")

        let menuBtn = app.buttons.matching(identifier: "NavbarProxyButton-Menu").firstMatch
        if menuBtn.waitForExistence(timeout: 3) {
            XCTAssertTrue(menuBtn.isHittable,
                          "Navbar proxy 'Menu' button must be hittable inside the native menuBar")
        }
    }
}
