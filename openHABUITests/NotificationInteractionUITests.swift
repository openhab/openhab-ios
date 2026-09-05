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

private enum InteractionFixture {
    static let toastTitle = "UITest Interaction Alert"
    static let toastMessage = "Motion detected."
    // JSON-encoded action list for UITestToastActions
    static let actionsJSON = #"[{"title":"Open Camera","action":"ui:/overview"}]"#
}

// MARK: - Test class

@MainActor
final class NotificationInteractionUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITest"] = "1"
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private var screen: CGRect { app.windows.firstMatch.frame }

    @discardableResult
    private func waitFor(_ text: String, timeout: TimeInterval = 4) -> XCUIElement {
        let el = app.staticTexts[text]
        XCTAssertTrue(el.waitForExistence(timeout: timeout), "Expected '\(text)' to appear within \(timeout)s")
        return el
    }

    private func waitForButton(_ label: String, timeout: TimeInterval = 4) -> XCUIElement {
        let el = app.buttons[label]
        XCTAssertTrue(el.waitForExistence(timeout: timeout), "Expected button '\(label)' to appear within \(timeout)s")
        return el
    }

    private func launchWithToastAndActions() {
        app.launchEnvironment["UITestToastTitle"] = InteractionFixture.toastTitle
        app.launchEnvironment["UITestToastMessage"] = InteractionFixture.toastMessage
        app.launchEnvironment["UITestToastActions"] = InteractionFixture.actionsJSON
        app.launch()
    }

    private func launchWithNotificationList() {
        app.launchEnvironment["UITestNotifications"] = "1"
        app.launch()
    }

    // MARK: - Toast action button tests

    func testToastActionButtonAppears() {
        launchWithToastAndActions()

        let title = waitFor(InteractionFixture.toastTitle)
        let button = waitForButton("Open Camera")
        XCTAssertTrue(button.isHittable, "Action button must be on-screen and hittable")

        // Layout assertions — loose thresholds so minor spacing changes don't break them.
        let s = screen
        // Toast banner must sit in the lower portion of the screen (not at screen centre).
        XCTAssertGreaterThan(title.frame.minY, s.height * 0.5,
                             "Toast title must appear in the lower half of the screen")
        // Action button must be on the right side (action control is right-aligned).
        XCTAssertGreaterThan(button.frame.minX, s.width * 0.45,
                             "Action button must be on the right side of the banner")
        // Action button and title must share roughly the same vertical centre (horizontal layout).
        XCTAssertLessThan(abs(button.frame.midY - title.frame.midY), 30,
                          "Action button and title must be at similar vertical positions")
    }

    func testToastActionButtonDismissesToast() {
        launchWithToastAndActions()

        waitFor(InteractionFixture.toastTitle)
        waitForButton("Open Camera").tap()

        let gone = NSPredicate(format: "exists == false")
        let expectation = expectation(for: gone, evaluatedWith: app.staticTexts[InteractionFixture.toastTitle])
        wait(for: [expectation], timeout: 2)
    }

    func testToastBodyTapWithActionsStillDismisses() {
        launchWithToastAndActions()

        let title = waitFor(InteractionFixture.toastTitle)
        title.tap()

        let gone = NSPredicate(format: "exists == false")
        let expectation = expectation(for: gone, evaluatedWith: app.staticTexts[InteractionFixture.toastTitle])
        wait(for: [expectation], timeout: 2)
    }

    // MARK: - Notification list interaction tests

    func testNotificationRowWithActionsShowsButton() {
        launchWithNotificationList()

        // Notifications sheet is auto-opened after 0.5 s; wait for mock data to load
        let alertText = waitFor("UITest Front Door Alert")
        let button = waitForButton("Open Camera")
        XCTAssertTrue(button.isHittable, "Action button must be visible in the notification row")

        // Layout assertions — action control must be right-aligned and inline with the row text.
        let s = screen
        XCTAssertGreaterThan(button.frame.minX, s.width * 0.45,
                             "Row action button must be on the right side of the screen")
        XCTAssertLessThan(abs(button.frame.midY - alertText.frame.midY), 30,
                          "Row action button and message text must share roughly the same vertical centre")
    }

    func testNotificationRowActionButtonDismissesSheet() {
        launchWithNotificationList()

        waitFor("UITest Front Door Alert")
        waitForButton("Open Camera").tap()

        let gone = NSPredicate(format: "exists == false")
        let expectation = expectation(for: gone, evaluatedWith: app.staticTexts["UITest Front Door Alert"])
        wait(for: [expectation], timeout: 2)
    }

    func testNotificationRowWithOnClickIsTappable() {
        launchWithNotificationList()

        // The row with onClickAction should be hittable (tappable region exists)
        let alertText = waitFor("UITest Front Door Alert")
        XCTAssertTrue(alertText.isHittable, "Notification row with on-click action must be hittable")
    }

    func testNotificationRowWithoutActionsHasNoActionButton() {
        launchWithNotificationList()

        // "UITest Regular Info" row should exist but have no "Open Camera" action button
        waitFor("UITest Regular Info")

        // The "Open Camera" button belongs only to the first row; query it via the second row's
        // containing element. Since we can't easily scope to a specific cell, we verify at the
        // list level: exactly one "Open Camera" button exists (for the first row only).
        let buttons = app.buttons.matching(identifier: "Open Camera")
        XCTAssertEqual(buttons.count, 1, "Only the row with actions should show an 'Open Camera' button")
    }
}
