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

// MARK: - Fixtures

/// A `menu.state` as Main UI's sidebar would send it. Labels are prefixed "UITest " to avoid
/// collision with the demo server's own pages.
private enum WebMenuFixture {
    private static let pages = #"""
    {"id":"pages","items":[
      {"id":"/page/uitest_kitchen","label":"UITest Kitchen","path":"/page/uitest_kitchen","icon":{"name":"f7:house"},"active":true}]}
    """#

    /// Signed in: Administration has its entries and the user's account, and the unlock entry is gone.
    static let unlocked = """
    {"sections":[\(pages),
      {"id":"settings","title":"UITest Administration","items":[
        {"id":"/settings/","label":"UITest Settings","path":"/settings/","icon":{"name":"f7:gear_alt_fill"},
         "children":[{"id":"/settings/things/","label":"UITest Things","path":"/settings/things/","icon":{"name":"f7:lightbulb"}}],
         "more":[{"id":"/settings/transformations/","label":"UITest Transformations","path":"/settings/transformations/"}]}]},
      {"id":"account","items":[{"id":"/account","label":"UITest Account","path":"/account"}]}]}
    """

    /// Signed out: no admin entries, only the entry that signs in.
    static let locked = """
    {"sections":[\(pages),
      {"id":"account","items":[{"id":"unlock","label":"UITest Unlock","icon":{"name":"f7:lock_shield_fill"}}]}]}
    """
}

// MARK: - Test class

/// The native menu's Main UI and Administration sections are built from the sidebar Main UI sends
/// over the bridge.
@MainActor
final class WebMenuUITests: XCTestCase {
    private var app: XCUIApplication!

    private var adminSettings: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "WebMenu-/settings/").firstMatch
    }

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITest"] = "1"
        app.launchEnvironment["UITestWebViewMode"] = "1"
    }

    override func tearDown() async throws {
        app = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func openMenu(sidebar: String = WebMenuFixture.unlocked) {
        app.launchEnvironment["UITestWebMenu"] = sidebar
        app.launch()
        let hamburger = app.buttons["HamburgerButton"]
        XCTAssertTrue(hamburger.waitForExistence(timeout: 8), "The menu button must be on screen")
        hamburger.tap()
    }

    private func element(_ identifier: String, timeout: TimeInterval = 4) -> XCUIElement {
        let el = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(el.waitForExistence(timeout: timeout), "Expected '\(identifier)' within \(timeout)s")
        return el
    }

    /// Opens or closes Administration. Its state is kept per home, so it may already be either.
    private func setAdministration(open: Bool) {
        guard adminSettings.waitForExistence(timeout: 1) != open else { return }
        element("WebMenuSection-settings").tap()
        if open {
            XCTAssertTrue(adminSettings.waitForExistence(timeout: 2), "Opening Administration shows its entries")
        } else {
            XCTAssertTrue(adminSettings.waitForNonExistence(timeout: 2), "Closing Administration hides its entries")
        }
    }

    // MARK: - Tests

    func testSidebarEntriesAppearInTheMenu() {
        openMenu()
        XCTAssertTrue(element("WebMenu-/page/uitest_kitchen").exists)
        XCTAssertTrue(element("WebMenuSection-settings").exists)
        XCTAssertTrue(app.staticTexts["UITest Administration"].exists, "Administration is a section of its own, titled by Main UI")
        setAdministration(open: true)
        XCTAssertTrue(element("WebMenu-/account").exists, "The user's account is listed in Administration")
    }

    func testLockedAdministrationShowsALockAndSignsIn() {
        openMenu(sidebar: WebMenuFixture.locked)
        XCTAssertTrue(element("WebMenu-/page/uitest_kitchen").exists)
        XCTAssertTrue(app.staticTexts["UITest Unlock"].exists, "A locked Administration is titled by the unlock entry")
        XCTAssertFalse(adminSettings.exists, "A locked Administration has no entries")
        XCTAssertFalse(app.buttons["WebMenu-unlock"].exists, "The section header stands for the unlock entry")

        // Tapping the header asks Main UI to sign in, which closes the menu, and never opens it.
        element("WebMenuSection-settings").tap()
        XCTAssertTrue(app.buttons["HamburgerButton"].waitForExistence(timeout: 4))
        XCTAssertFalse(adminSettings.exists)
    }

    func testAdministrationIsRemembered() {
        openMenu()
        setAdministration(open: false)
        setAdministration(open: true)

        app.terminate()
        openMenu()
        XCTAssertTrue(adminSettings.waitForExistence(timeout: 4), "Administration stays open after a restart")

        setAdministration(open: false)
        app.terminate()
        openMenu()
        XCTAssertTrue(element("WebMenuSection-settings").exists)
        XCTAssertFalse(adminSettings.exists, "Administration stays closed after a restart")
    }

    func testAdminEntriesHaveNoSubmenuToggle() {
        openMenu()
        setAdministration(open: true)
        let toggle = app.descendants(matching: .any).matching(identifier: "WebMenuToggle-/settings/").firstMatch
        XCTAssertFalse(toggle.exists, "Admin entries open their page; there is no submenu toggle")
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "WebMenu-/settings/things/").firstMatch.exists)
    }
}
