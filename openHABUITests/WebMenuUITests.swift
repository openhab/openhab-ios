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
    static let json = #"""
    {"sections":[
      {"id":"pages","items":[
        {"id":"/page/uitest_kitchen","label":"UITest Kitchen","path":"/page/uitest_kitchen","icon":{"name":"f7:house"},"active":true}]},
      {"id":"settings","title":"UITest Administration","items":[
        {"id":"/settings/","label":"UITest Settings","path":"/settings/","icon":{"name":"f7:gear_alt_fill"},
         "children":[{"id":"/settings/things/","label":"UITest Things","path":"/settings/things/","icon":{"name":"f7:lightbulb"}}],
         "more":[{"id":"/settings/transformations/","label":"UITest Transformations","path":"/settings/transformations/"}]}]},
      {"id":"account","items":[{"id":"unlock","label":"UITest Unlock","icon":{"name":"f7:lock_shield_fill"}}]}]}
    """#
}

// MARK: - Test class

/// The native menu's Main UI section is built from the sidebar Main UI sends over the bridge.
@MainActor
final class WebMenuUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITest"] = "1"
        app.launchEnvironment["UITestWebViewMode"] = "1"
        app.launchEnvironment["UITestWebMenu"] = WebMenuFixture.json
    }

    override func tearDown() async throws {
        app = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func openMenu() {
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

    private var adminSettings: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "WebMenu-/settings/").firstMatch
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
        XCTAssertTrue(app.staticTexts["UITest Administration"].exists, "A section's title is its row")
        XCTAssertTrue(element("WebMenu-unlock").exists, "An entry without a path still shows")
        setAdministration(open: true)
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

    func testSubmenuOpensAndShowsAll() {
        openMenu()
        setAdministration(open: true)
        let things = app.descendants(matching: .any).matching(identifier: "WebMenu-/settings/things/").firstMatch
        XCTAssertFalse(things.exists, "A submenu starts closed")

        element("WebMenuToggle-/settings/").tap()
        XCTAssertTrue(things.waitForExistence(timeout: 2), "Opening Settings shows the entries the sidebar shows")

        let transformations = app.descendants(matching: .any)
            .matching(identifier: "WebMenu-/settings/transformations/").firstMatch
        XCTAssertFalse(transformations.exists, "The rest of the submenu waits behind Show all")
        element("WebMenuShowAll-/settings/").tap()
        XCTAssertTrue(transformations.waitForExistence(timeout: 2), "Show all lists the rest of the submenu")
    }
}
