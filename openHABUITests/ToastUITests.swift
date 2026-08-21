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

private enum Toast {
    struct Payload {
        let title: String
        let message: String
    }

    // Titles are prefixed "UITest " to avoid collision with demo-sitemap labels.
    static let short = Payload(
        title: "UITest Alert",
        message: "Motion detected."
    )
    static let longTitle = Payload(
        title: "UITest Security System Armed Away — All sensors active",
        message: "OK"
    )
    static let longMessage = Payload(
        title: "UITest Alert",
        message: "Your front door has been open for more than 10 minutes. Please close it to preserve temperature."
    )
    static let veryLongBoth = Payload(
        title: "UITest Home Automation System Notification — Urgent",
        message: "Multiple sensors triggered: front door open, garage door open, motion in living room."
    )
}

// MARK: - Test class

@MainActor
final class ToastUITests: XCTestCase {
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

    private func launchWithToast(_ payload: Toast.Payload) {
        app.launchEnvironment["UITestToastTitle"] = payload.title
        app.launchEnvironment["UITestToastMessage"] = payload.message
        app.launch()
    }

    @discardableResult
    private func waitFor(_ text: String, timeout: TimeInterval = 4) -> XCUIElement {
        let el = app.staticTexts[text]
        XCTAssertTrue(el.waitForExistence(timeout: timeout), "Expected '\(text)' to appear within \(timeout)s")
        return el
    }

    // The screen frame as seen by XCUITest — use the app's key window as proxy.
    private var screenFrame: CGRect {
        app.windows.firstMatch.frame
    }

    private func assertWithinScreen(_ el: XCUIElement, label: String) {
        let frame = el.frame
        let screen = screenFrame
        XCTAssertGreaterThanOrEqual(frame.minX, screen.minX, "\(label): left edge overflows screen (\(frame.minX) < \(screen.minX))")
        XCTAssertLessThanOrEqual(frame.maxX, screen.maxX, "\(label): right edge overflows screen (\(frame.maxX) > \(screen.maxX))")
    }

    // MARK: - Functionality tests

    func testShortToastAppears() {
        launchWithToast(Toast.short)

        let title = waitFor(Toast.short.title)
        XCTAssertTrue(title.isHittable, "Toast title must be on-screen and hittable")

        let message = waitFor(Toast.short.message)
        XCTAssertTrue(message.exists)
    }

    func testTapDismissesToast() {
        launchWithToast(Toast.short)

        let title = waitFor(Toast.short.title)
        title.tap()

        let gone = NSPredicate(format: "exists == false")
        let expectation = expectation(for: gone, evaluatedWith: app.staticTexts[Toast.short.title])
        wait(for: [expectation], timeout: 2)
    }

    func testAutoDismissAfterTimeout() {
        launchWithToast(Toast.short)
        waitFor(Toast.short.title)

        // toast duration is 5 s; allow 7 s total (5 s + 2 s for animation + scheduling jitter)
        let gone = NSPredicate(format: "exists == false")
        let expectation = expectation(for: gone, evaluatedWith: app.staticTexts[Toast.short.title])
        wait(for: [expectation], timeout: 7)
    }

    // MARK: - Dimension tests

    func testShortToastWithinScreenBounds() {
        launchWithToast(Toast.short)
        assertWithinScreen(waitFor(Toast.short.title), label: "short title")
        assertWithinScreen(waitFor(Toast.short.message), label: "short message")
    }

    func testLongTitleWithinScreenBounds() {
        launchWithToast(Toast.longTitle)
        assertWithinScreen(waitFor(Toast.longTitle.title), label: "long title")
    }

    func testLongMessageWithinScreenBounds() {
        launchWithToast(Toast.longMessage)
        assertWithinScreen(waitFor(Toast.longMessage.title), label: "long-message title")
        assertWithinScreen(waitFor(Toast.longMessage.message), label: "long message")
    }

    func testVeryLongBothWithinScreenBounds() {
        launchWithToast(Toast.veryLongBoth)
        assertWithinScreen(waitFor(Toast.veryLongBoth.title), label: "very-long title")
        assertWithinScreen(waitFor(Toast.veryLongBoth.message), label: "very-long message")
    }

    // MARK: - Position test

    func testToastAppearsInLowerHalfOfScreen() {
        launchWithToast(Toast.short)
        let title = waitFor(Toast.short.title)
        let screenMidY = screenFrame.midY
        XCTAssertGreaterThan(title.frame.midY, screenMidY, "Toast must appear in the lower half of the screen")
    }
}
