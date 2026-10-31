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

/// The "Hide Status and Navigation Bar" setting: the bars are gone, and holding three fingers
/// brings them back for a while.
///
/// XCUITest cannot hold three fingers on the screen, so `UITestRevealBarsAfter` runs the same
/// reveal as the gesture does (`BarVisibility.reveal()`) that many seconds after the bars first hide. The
/// gesture's rules are covered by `ThreeFingerHoldTrackerTests`.
@MainActor
final class HiddenBarsUITests: XCTestCase {
    private static let pageHTML = """
    <!DOCTYPE html><html>
    <head><meta name='viewport' content='width=device-width,initial-scale=1,viewport-fit=cover'></head>
    <body><button aria-label='UITest Hidden Bars Page'>page</button></body></html>
    """

    private var app: XCUIApplication!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.useEnglishLocale()
        app.launchEnvironment["UITest"] = "1"
        app.launchEnvironment["UITestHideBars"] = "1"
        app.launchEnvironment["UITestWebViewMode"] = "1"
        app.launchEnvironment["UITestInjectHTML"] = Data(Self.pageHTML.utf8).base64EncodedString()
        app.launchEnvironment["UITestBarRevealSeconds"] = "3"
    }

    override func tearDown() async throws {
        app = nil
        try await super.tearDown()
    }

    /// What the app reports about its bars: "hidden" or "shown". The menu button alone cannot
    /// tell a bar that has not been hidden yet from one that has come back.
    private func waitForBars(_ state: String, timeout: TimeInterval = 10) {
        let report = app.staticTexts["UITestReport-barsHidden"]
        let reached = expectation(for: NSPredicate(format: "label == %@", state), evaluatedWith: report)
        wait(for: [reached], timeout: timeout)
    }

    private func waitForPage() {
        let page = app.webViews.firstMatch.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "UITest Hidden Bars Page")).firstMatch
        XCTAssertTrue(page.waitForExistence(timeout: 10), "The page should load")
    }

    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval) {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        wait(for: [gone], timeout: timeout)
    }

    /// The menu button is gone once the page has loaded.
    func testMenuButtonIsHiddenOnceThePageHasLoaded() {
        app.launch()
        waitForPage()
        waitUntilGone(app.buttons["HamburgerButton"], timeout: 10)
    }

    /// The reveal shows the menu button again and takes it away after the reveal time.
    func testRevealShowsTheMenuButtonForAWhile() {
        app.launchEnvironment["UITestRevealBarsAfter"] = "2"
        app.launch()

        let menuButton = app.buttons["HamburgerButton"]
        waitForBars("hidden")
        waitUntilGone(menuButton, timeout: 5)

        waitForBars("shown", timeout: 5)
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5), "The reveal should bring the menu button back")

        waitForBars("hidden", timeout: 8)
        waitUntilGone(menuButton, timeout: 5)
    }

    /// Guided Access is iOS's own kiosk mode, with its own way out: the bars are hidden without
    /// the setting, and the reveal does nothing.
    func testGuidedAccessHidesTheBarsAndTheRevealDoesNothing() {
        app.launchEnvironment["UITestHideBars"] = nil
        app.launchEnvironment["UITestGuidedAccess"] = "1"
        app.launchEnvironment["UITestRevealBarsAfter"] = "2"
        app.launch()

        waitForPage()
        let menuButton = app.buttons["HamburgerButton"]
        waitUntilGone(menuButton, timeout: 10)

        XCTAssertFalse(menuButton.waitForExistence(timeout: 6), "The reveal must not bring the bar back")
    }
}
