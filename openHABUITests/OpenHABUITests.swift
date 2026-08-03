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

import os.log
import XCTest

class OpenHABUITests: XCTestCase {
    let runWebViewAndSitemap = true // To accelerate testing of settings set to false

    override func setUp() async throws {
        try await super.setUp()

        let app = await XCUIApplication()
        await MainActor.run {
            app.launchEnvironment = ["UITest": "1"]
        }
        continueAfterFailure = false
        await setupSnapshot(app)
        await app.launch()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testShots() {
        let app = XCUIApplication()
        app.activate()

        let hamburgerButton = app.navigationBars.buttons["line.3.horizontal"]
        hamburgerButton.tap()
        sleep(3)

        if runWebViewAndSitemap {
            app.staticTexts["Home"].tap()
            sleep(10)
            snapshot("0_MainUI")

            // Locations Tab
            let webViewsQuery = app.webViews.webViews.webViews
            webViewsQuery.links["placemark_fill Locations"].tap()
            sleep(2)
            snapshot("1_Locations")

            webViewsQuery.staticTexts["Living Room"].tap()
            sleep(2)
            snapshot("2_LivingRoom")
            // Close the Living Room overlay.
            // Query through otherElements["openHAB"] no longer matches; find the close link directly.
            let closeButton = webViewsQuery.links.matching(identifier: "multiply_circle_fill").firstMatch
            if closeButton.waitForExistence(timeout: 5) {
                closeButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            sleep(2)

            // Web view text elements expose content as label, not identifier.
            // Use predicate-based matching throughout web navigation.
            let floorplansEl = webViewsQuery.staticTexts.matching(NSPredicate(format: "label == 'Floorplans'")).firstMatch
            var menuStaticText: XCUIElement?
            // if we have a left side menu, then use it (large screens like 12.9 inch iPad will not)
            if !floorplansEl.exists {
                // Scroll to top so the web nav header (and menu button) is visible
                app.webViews.firstMatch.swipeDown()
                sleep(1)
                // Left side menu in webUI — match by label since web elements use label not identifier
                let menuEl = webViewsQuery.staticTexts.matching(NSPredicate(format: "label == 'menu'")).firstMatch
                if menuEl.waitForExistence(timeout: 5) {
                    menuEl.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                    menuStaticText = menuEl
                }
                sleep(1)
            }

            let floorplansTarget = webViewsQuery.staticTexts.matching(NSPredicate(format: "label == 'Floorplans'")).firstMatch
            if floorplansTarget.waitForExistence(timeout: 5) {
                floorplansTarget.tap()
            }
            sleep(10)
            snapshot("3_Floorplans")
            sleep(1)

            // Close the sidebar if it was opened on iPhone to navigate to Floorplans.
            // When the sidebar is open its backdrop intercepts the first tap on the exit button,
            // closing the sidebar but not delivering the click to the link.
            menuStaticText?.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            sleep(1)

            // Exit to native app: tap the exit button in the MainUI top-nav.
            // The button calls OHApp.exitToApp() → showSideMenu(). Use label predicate since
            // web view elements expose content as label, not accessibility identifier.
            let exitLink = webViewsQuery.links.matching(NSPredicate(format: "label == 'square_arrow_right'")).firstMatch
            if exitLink.waitForExistence(timeout: 5) {
                exitLink.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            } else if hamburgerButton.waitForExistence(timeout: 3) {
                hamburgerButton.tap()
            }
            sleep(3)

            // The native SideMenu (right drawer) is now open.
            // Tap "Smart Home" — the main demo sitemap on demo.openhab.org.
            // Drawer buttons are matched by label since sitemapSection uses Text(sitemap.label)
            // with no explicit accessibilityIdentifier.
            let smartHomeButton = app.buttons.matching(NSPredicate(format: "label == 'Smart Home'")).firstMatch
            if smartHomeButton.waitForExistence(timeout: 5) {
                smartHomeButton.tap()
            }
            sleep(8)
            snapshot("4_MainSitemap")

            // SwiftUI List renders as UICollectionView on iOS 16+, not UITableView.
            app.collectionViews.firstMatch.swipeUp()
            sleep(3)
            snapshot("5_WidgetOverview")

            hamburgerButton.tap()
            sleep(3)
        }
        // "settings" is set via .accessibilityLabel not .accessibilityIdentifier in DrawerView,
        // so subscript ["settings"] fails; match by label predicate instead.
        app.buttons.matching(NSPredicate(format: "label == 'settings'")).firstMatch.tap()
        sleep(2)
        snapshot("7_Settings_Demo")

        // The Demo Mode toggle has no explicit accessibilityIdentifier; SwiftUI sets the
        // identifier to the bool value string ("1"/"0"), which is ambiguous when multiple
        // switches are ON. Match by label instead.
        let switch1 = app.switches.matching(NSPredicate(format: "label == 'Demo Mode'")).firstMatch
        switch1.tap()
        sleep(2)
        snapshot("8_Settings_Server")
    }
}
