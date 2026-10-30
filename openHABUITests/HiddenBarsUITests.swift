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

    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval) {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        wait(for: [gone], timeout: timeout)
    }

    /// The bars are shown while the page loads, as a safety net, and go once it has.
    func testMenuButtonIsHiddenOnceThePageHasLoaded() {
        app.launch()
        let page = app.webViews.firstMatch.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "UITest Hidden Bars Page")).firstMatch
        XCTAssertTrue(page.waitForExistence(timeout: 10))

        waitUntilGone(app.buttons["HamburgerButton"], timeout: 10)
    }

    /// The reveal shows the menu button again and takes it away after the reveal time.
    func testRevealShowsTheMenuButtonForAWhile() {
        app.launchEnvironment["UITestRevealBarsAfter"] = "2"
        app.launch()

        let menuButton = app.buttons["HamburgerButton"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 10), "The bar is shown while the page loads")
        waitUntilGone(menuButton, timeout: 10)

        XCTAssertTrue(menuButton.waitForExistence(timeout: 10), "The reveal should bring the menu button back")
        waitUntilGone(menuButton, timeout: 6)
    }
}
