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

@MainActor
final class ToolbarMenuUITests: XCTestCase {
    private var app: XCUIApplication!

    private var appSettingsRow: XCUIElement {
        app.buttons["App Settings"]
    }

    private var sitemapsHeader: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ==[c] 'Sitemaps'")).firstMatch
    }

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITest"] = "1"
        app.launchEnvironment["UITestOpenMenu"] = "1"
    }

    override func tearDown() async throws {
        app = nil
        try await super.tearDown()
    }

    /// Pulling the menu down triggers a reload that keeps the menu open and populated —
    /// unlike the header's reload button, which clears the data and closes the menu.
    func testPullToRefreshKeepsMenuOpenAndPopulated() {
        app.launch()

        XCTAssertTrue(appSettingsRow.waitForExistence(timeout: 5), "Menu should open via UITestOpenMenu")
        XCTAssertTrue(sitemapsHeader.waitForExistence(timeout: 20), "Demo sitemaps should load into the open menu")

        let scrollView = app.scrollViews["ToolbarMenuScrollView"]
        XCTAssertTrue(scrollView.exists, "Menu scroll view should be present")

        let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let end = start.withOffset(CGVector(dx: 0, dy: 250))
        start.press(forDuration: 0.1, thenDragTo: end)

        XCTAssertTrue(appSettingsRow.waitForExistence(timeout: 2), "Menu should stay open after pull-to-refresh")
        XCTAssertTrue(sitemapsHeader.waitForExistence(timeout: 20), "Sitemaps should remain listed after pull-to-refresh")
        XCTAssertTrue(sitemapsHeader.isHittable, "Sitemaps header should be interactable once the refresh settles")
    }
}
