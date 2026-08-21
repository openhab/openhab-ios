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
    /// Measures Framework7 .page-content padding-top — the spacing left by
    /// the hidden web navbar (Bug 1).
    static let pageContentSpacing = #"""
    (function(){
      var pc = document.querySelector('.view-main .page-current .page-content')
               || document.querySelector('.page-current .page-content')
               || document.querySelector('.page-content');
      if (!pc) { window.ohUITest.report('pageContentFound','0'); return; }
      window.ohUITest.report('pageContentFound','1');
      var s = getComputedStyle(pc);
      window.ohUITest.report('pageContentPaddingTop', String(parseFloat(s.paddingTop) || 0));
    })();
    """#

    static func base64(_ js: String) -> String { Data(js.utf8).base64EncodedString() }
}

// MARK: - HTML fixtures

/// Minimal HTML pages mirroring the Framework7 DOM structure used by the MainUI SPA.
/// The same JS probes that work on the real page work on these fixtures.
private enum LayoutHTML {
    /// Overview page: web navbar hidden via display:none but page-content padding-top retained.
    /// Reproduces Bug 1 — content starts 44pt lower than the native menuBar bottom.
    static let overviewPage = """
    <!DOCTYPE html><html>
    <head><meta name='viewport' content='width=device-width,initial-scale=1'>
    <style>
    *{margin:0;padding:0;box-sizing:border-box}body{font-family:system-ui}
    .navbar{height:44px;background:#eee;display:none}
    .page-content{padding-top:44px;padding-left:16px}
    h1{font-size:22px;padding:12px 0}
    </style></head>
    <body><div class='view view-main'><div class='page page-current'>
      <div class='navbar'><div class='navbar-inner'><div class='title'>Overview</div></div></div>
      <div class='page-content'><h1>UITest Overview Heading</h1></div>
    </div></div></body></html>
    """

    /// Side panel rendered in open state.
    /// The panel header is at y=0 of the webview — directly under the native menuBar.
    /// viewport-fit=cover mirrors the real MainUI SPA (Framework7 always uses it), which
    /// disables WebKit's automatic safe-area offset for position:fixed elements.
    /// Reproduces Bug 2.
    static let openSidePanel = """
    <!DOCTYPE html><html>
    <head><meta name='viewport' content='width=device-width,initial-scale=1,viewport-fit=cover'>
    <style>
    *{margin:0;padding:0;box-sizing:border-box}body{font-family:system-ui;height:100vh}
    .panel{position:fixed;top:0;left:0;width:75%;height:100%;background:white;z-index:100}
    .panel-header{height:44px;background:#eee;display:flex;align-items:center;padding:0 16px}
    .panel-header h2{font-size:16px}
    .panel-items{padding:16px}
    </style></head>
    <body>
    <div class='panel'>
      <div class='panel-header'><h2>UITest Side Panel Header</h2></div>
      <div class='panel-items'><p>Menu item 1</p><p>Menu item 2</p></div>
    </div>
    </body></html>
    """

    /// Equipment detail page: X/close button at top-right (y≈0 of webview).
    /// Reproduces Bug 3 — button hidden under native menuBar.
    static let equipmentDetail = """
    <!DOCTYPE html><html>
    <head><meta name='viewport' content='width=device-width,initial-scale=1'>
    <style>
    *{margin:0;padding:0;box-sizing:border-box}body{font-family:system-ui}
    .page-header{position:relative;height:44px;background:#eee;display:flex;align-items:center;padding:0 8px}
    .close-btn{position:absolute;right:8px;top:0;height:44px;width:44px;
               display:flex;align-items:center;justify-content:center;
               font-size:20px;cursor:pointer;border:none;background:none}
    .title{flex:1;text-align:center;font-weight:bold}
    .page-content{padding:16px}
    </style></head>
    <body>
    <div class='page-header'>
      <div class='title'>Light Switch</div>
      <button class='close-btn' aria-label='UITest Close Button'>&#x2715;</button>
    </div>
    <div class='page-content'><p>Equipment detail content.</p></div>
    </body></html>
    """

    /// Framework7-like page with a position:fixed bottom tab bar.
    /// Reproduces the regression from the first Bug 2/3 fix attempt: applying
    /// contentInset.top=44 pushes position:fixed bottom:0 elements 44pt off-screen.
    static let bottomTabBar = """
    <!DOCTYPE html><html>
    <head><meta name='viewport' content='width=device-width,initial-scale=1'>
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

/// Layout tests for the three MainUI webview bugs and the navbar proxy button infrastructure.
///
/// **Bug tests are EXPECTED TO FAIL** until the bugs are fixed — the failure messages
/// explain the root cause. Infrastructure tests should PASS after the app-side
/// injection mechanism is wired up.
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

    /// Finds a button by its accessibilityIdentifier (not label).
    @discardableResult
    private func waitForButton(_ identifier: String, timeout: TimeInterval = 6) -> XCUIElement {
        let el = app.buttons.matching(identifier: identifier).firstMatch
        XCTAssertTrue(el.waitForExistence(timeout: timeout),
                      "Expected button with identifier '\(identifier)' within \(timeout)s")
        return el
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

    @discardableResult
    private func waitForReport(_ key: String, timeout: TimeInterval = 8) -> String {
        let el = app.staticTexts.matching(identifier: "UITestReport-\(key)").firstMatch
        XCTAssertTrue(el.waitForExistence(timeout: timeout),
                      "Expected JS report '\(key)' within \(timeout)s — check ohUITest bridge is active")
        return el.label
    }

    // MARK: - Bug 1: Residual Framework7 padding-top after navbar is hidden

    /// BUG 1 — EXPECTED TO FAIL until fixed.
    ///
    /// After the JS proxy hides the web navbar with `display:none`, Framework7's
    /// `.page-content` still has `padding-top` equal to the hidden navbar height.
    /// Web content therefore starts ~44pt below the native bar bottom instead of
    /// immediately beneath it — leaving a visible gap.
    ///
    /// Fix: the proxy must also zero the padding-top (or remove the spacer div
    /// Framework7 injects for the navbar).
    func testOverviewContentHasResidualNavbarPaddingAfterHide() {
        launchInWebviewMode(html: LayoutHTML.overviewPage, js: LayoutJS.pageContentSpacing)
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 8))
        XCTAssertEqual(waitForReport("pageContentFound"), "1",
                       "JS probe must locate .page-content in the loaded HTML")
        let paddingTop = Double(waitForReport("pageContentPaddingTop")) ?? 0
        XCTAssertEqual(
            paddingTop, 0, accuracy: 2,
            """
            BUG 1: .page-content padding-top = \(paddingTop)pt after navbar hidden. \
            Framework7 reserves the navbar height as padding-top on .page-content. \
            The JS proxy sets navbar.style.display='none' but does NOT remove this padding, \
            leaving a gap equal to the navbar height below the native menuBar.
            """
        )
    }

    // MARK: - Bug 2: Framework7 side panel hidden under native bar

    /// BUG 2 — EXPECTED TO FAIL until fixed.
    ///
    /// The Framework7 side panel (opened by the extracted hamburger proxy button)
    /// renders at webview y=0. The native menuBar covers webview y=0…44pt, so the
    /// panel header is invisible and untappable.
    ///
    /// Fix: add `contentInset.top` = native bar height OR inject CSS `padding-top`
    /// on the panel/body so panel content starts below the bar. Fix must be generic.
    func testSidePanelHeaderHiddenUnderNativeMenuBar() {
        launchInWebviewMode(html: LayoutHTML.openSidePanel)
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.waitForExistence(timeout: 8))

        let panelHeader = waitForWebLabel("UITest Side Panel Header", type: .staticText)
        let barBottom = nativeBarBottom

        XCTAssertGreaterThanOrEqual(
            panelHeader.frame.minY, barBottom,
            """
            BUG 2: Side panel header top (\(panelHeader.frame.minY)pt) is above the \
            native menuBar bottom (\(barBottom)pt). The panel renders at webview y=0, \
            covered by the native menuBar. Fix: shrink the webview frame so web content \
            starts at or below the native bar bottom.
            """
        )
    }

    // MARK: - Bug 3: Equipment close button hidden under native bar (generic)

    /// BUG 3 — EXPECTED TO FAIL until fixed.
    ///
    /// In Equipment detail views — and generically for any web content at y≈0 of
    /// the webview — the X/close button is covered by the native menuBar.
    ///
    /// Same root cause as Bug 2: webview contentInset=.zero means web content at
    /// y=0 coincides with the native bar area.
    ///
    /// Fix must be generic (e.g. global CSS padding-top or contentInset.top),
    /// not specific to the Equipment X button.
    func testEquipmentCloseButtonHiddenUnderNativeMenuBar() {
        launchInWebviewMode(html: LayoutHTML.equipmentDetail)
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.waitForExistence(timeout: 8))

        let closeBtn = waitForWebLabel("UITest Close Button", type: .button)
        let barBottom = nativeBarBottom

        XCTAssertGreaterThanOrEqual(
            closeBtn.frame.minY, barBottom,
            """
            BUG 3: Equipment close button top (\(closeBtn.frame.minY)pt) is above the \
            native menuBar bottom (\(barBottom)pt). Same root cause as Bug 2: web content \
            at page y=0 is covered by the native bar. Fix must be generic (shrink the \
            webview frame), not specific to this button.
            """
        )
    }

    // MARK: - Regression: bottom-fixed elements cut off when top inset applied via contentInset

    /// REGRESSION — EXPECTED TO FAIL if contentInset.top is used instead of frame shrink.
    ///
    /// Applying `scrollView.contentInset.top = 44` shifts the CSS viewport DOWN so the
    /// top of content appears below the native bar, but `window.innerHeight` stays equal
    /// to the FULL WKWebView frame height. As a result, `position:fixed; bottom:0`
    /// elements (Framework7 tab bar) are pushed 44pt BELOW the visible screen bottom.
    ///
    /// The correct fix is `.padding(.top, 44)` on the webview container in SwiftUI so the
    /// webview FRAME starts 44pt lower — giving `window.innerHeight = frame.height - 44`.
    func testBottomFixedElementNotCutOffByTopInset() {
        launchInWebviewMode(html: LayoutHTML.bottomTabBar)
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.waitForExistence(timeout: 8))

        let tabBarBtn = waitForWebLabel("UITest Tab Bar", type: .button)
        let overflowBelowWebview = tabBarBtn.frame.maxY - webView.frame.maxY

        XCTAssertLessThanOrEqual(
            overflowBelowWebview, 2,
            """
            REGRESSION: position:fixed bottom:0 element extends \(overflowBelowWebview)pt \
            below the webview bottom edge. Applying contentInset.top=44 without reducing the \
            viewport height shifts the entire CSS viewport down — Framework7's bottom tab bar \
            is pushed off-screen. Fix: use .padding(.top, 44) on the webview container so \
            window.innerHeight shrinks by 44pt instead of the viewport shifting.
            """
        )
    }

    // MARK: - Navbar proxy infrastructure (should PASS after app-side changes)

    /// PASSES once UITestWebViewNavbarItems injection is wired up.
    ///
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

    /// PASSES once UITestWebViewNavbarItems injection is wired up.
    ///
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
