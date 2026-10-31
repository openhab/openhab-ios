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

/// The Administration section of the menu follows who is signed in to Main UI on the origin in
/// use: a spinner while the page has not said yet, a lock once it is known that nobody is signed
/// in (or the page never said), the entries once an administrator is.
@MainActor
final class AdministrationAccessUITests: XCTestCase {
    private var app: XCUIApplication!

    private let signInServer = """
    {"version":"5.0.0","endpoints":["auth","items","things","rules","ui","addons"],\
    "pages":[{"uid":"uitest_members","label":"UITest Members","visibleTo":["role:user"]},\
    {"uid":"uitest_all","label":"UITest All"}],"sitemaps":[{"name":"home","label":"Smart Home"}]}
    """
    private let openServer = #"{"version":"5.0.0","endpoints":["items","things","rules","ui","addons"],"sitemaps":[{"name":"home","label":"Smart Home"}]}"#
    private let administrator = #"{"user":{"name":"root","roles":["administrator"]},"noAuth":false}"#
    private let plainUser = #"{"user":{"name":"ann","roles":["user"]},"noAuth":false}"#
    private let signedOut = #"{"user":null,"noAuth":false}"#
    /// Keeps the sign-in unknown whatever the page behind reports: on a sitemap the real Main UI
    /// loads in the background and says within seconds.
    private let pending = "pending"

    private var header: XCUIElement {
        app.buttons["AdministrationSection"]
    }

    private var settingsEntry: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "MainUIEntry-settings").firstMatch
    }

    private var lock: XCUIElement {
        header.images["lock.fill"]
    }

    private var spinner: XCUIElement {
        header.activityIndicators.firstMatch
    }

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.useEnglishLocale()
        app.launchEnvironment["UITest"] = "1"
        app.launchEnvironment["UITestOpenMenu"] = "1"
    }

    override func tearDown() async throws {
        app = nil
        try await super.tearDown()
    }

    private func launch(server: String, auth: String? = nil, timeout: Int? = nil) {
        app.launchEnvironment["UITestServer"] = server
        if let auth {
            app.launchEnvironment["UITestWebAuth"] = auth
        }
        if let timeout {
            app.launchEnvironment["UITestAuthTimeout"] = String(timeout)
        }
        app.launch()
        XCTAssertTrue(app.buttons["App Settings"].waitForExistence(timeout: 8), "The menu opens via UITestOpenMenu")
        XCTAssertTrue(header.waitForExistence(timeout: 8), "Administration is in the menu")
    }

    // MARK: - Not known yet

    func testAdministrationShowsASpinnerWhileNobodyHasSaid() {
        launch(server: signInServer, timeout: 600)
        XCTAssertTrue(spinner.waitForExistence(timeout: 4), "Administration shows that it is finding out")
        XCTAssertFalse(lock.exists, "There is no lock while it is not known that nobody is signed in")
        XCTAssertFalse(settingsEntry.exists)
    }

    func testTappingAdministrationWhileFindingOutDoesNothing() {
        launch(server: signInServer, timeout: 600)
        XCTAssertTrue(spinner.waitForExistence(timeout: 4))
        header.tap()
        XCTAssertTrue(app.buttons["App Settings"].exists, "The menu stays open: nothing is signed in to or opened")
        XCTAssertTrue(spinner.exists)
    }

    func testRestrictedPagesStayHiddenWhileFindingOut() {
        launch(server: signInServer, timeout: 600)
        XCTAssertTrue(app.buttons["UITest All"].waitForExistence(timeout: 4), "Pages for everybody show")
        XCTAssertFalse(app.buttons["UITest Members"].exists, "Pages limited to a role stay hidden until it is known")
    }

    func testMenuIsUsableWhileFindingOut() {
        launch(server: signInServer, timeout: 600)
        XCTAssertTrue(spinner.waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["App Settings"].isHittable, "The rest of the menu works while Administration waits")
    }

    func testOffersSigningInWhenNobodyHasSaidInTime() {
        launch(server: signInServer, timeout: 2)
        XCTAssertTrue(lock.waitForExistence(timeout: 8), "A page that never says ends up as a lock")
        XCTAssertFalse(spinner.exists)
    }

    // MARK: - Known

    func testSignedOutShowsALockAtOnce() {
        launch(server: signInServer, auth: signedOut, timeout: 600)
        XCTAssertTrue(lock.waitForExistence(timeout: 4))
        XCTAssertFalse(spinner.exists)
        XCTAssertFalse(settingsEntry.exists)
    }

    func testAdministratorSeesTheEntries() {
        launch(server: signInServer, auth: administrator, timeout: 600)
        XCTAssertTrue(settingsEntry.waitForExistence(timeout: 4), "An administrator gets Settings")
        XCTAssertFalse(lock.exists)
        XCTAssertFalse(spinner.exists)
        XCTAssertTrue(app.buttons["UITest All"].exists)
        XCTAssertFalse(app.buttons["UITest Members"].exists, "A page limited to another role stays hidden from an administrator")
    }

    func testUserWithoutTheAdministratorRoleSeesTheAccountOnly() {
        launch(server: signInServer, auth: plainUser, timeout: 600)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "MainUIEntry-account").firstMatch.waitForExistence(timeout: 4))
        XCTAssertFalse(settingsEntry.exists, "Settings is for administrators")
        XCTAssertTrue(app.buttons["UITest Members"].waitForExistence(timeout: 2), "A user sees the pages limited to their role")
    }

    func testServerWithoutSignInOpensEverythingWithoutWaiting() {
        launch(server: openServer, timeout: 600)
        XCTAssertTrue(settingsEntry.waitForExistence(timeout: 4), "Without sign-in everybody is an administrator")
        XCTAssertFalse(spinner.exists)
        XCTAssertFalse(lock.exists)
    }

    // MARK: - Entries and state

    private var accountEntry: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "MainUIEntry-account").firstMatch
    }

    /// Opens or closes Administration. Its state is kept per home, so it may already be either.
    private func setAdministration(open: Bool) {
        guard settingsEntry.waitForExistence(timeout: 2) != open else { return }
        header.tap()
        if open {
            XCTAssertTrue(settingsEntry.waitForExistence(timeout: 2), "Opening Administration shows its entries")
        } else {
            XCTAssertTrue(settingsEntry.waitForNonExistence(timeout: 2), "Closing Administration hides its entries")
        }
    }

    /// Starts the app again with the same launch environment, as after the user quit it.
    private func relaunch() {
        app.terminate()
        app.launch()
        XCTAssertTrue(header.waitForExistence(timeout: 8), "Administration is in the menu after a restart")
    }

    func testAdministratorSeesTheSignedInAccount() {
        launch(server: signInServer, auth: administrator, timeout: 600)
        setAdministration(open: true)
        // The administrator's entries push the account below the fold of a short menu.
        let menu = app.scrollViews["ToolbarMenuScrollView"]
        for _ in 0 ..< 3 where !accountEntry.exists {
            menu.swipeUp()
        }
        XCTAssertTrue(accountEntry.exists, "The signed-in user's account is listed in Administration")
    }

    func testTappingTheLockSignsInAndClosesTheMenu() {
        launch(server: signInServer, auth: signedOut, timeout: 600)
        XCTAssertTrue(lock.waitForExistence(timeout: 4))
        header.tap()
        XCTAssertTrue(app.buttons["App Settings"].waitForNonExistence(timeout: 4), "Main UI signs in on its own page, so the menu closes")
        XCTAssertFalse(settingsEntry.exists, "A locked Administration never opens")
    }

    func testAdministrationIsRemembered() {
        launch(server: signInServer, auth: administrator, timeout: 600)
        setAdministration(open: false)
        setAdministration(open: true)

        relaunch()
        XCTAssertTrue(settingsEntry.waitForExistence(timeout: 4), "Administration stays open after a restart")

        setAdministration(open: false)
        relaunch()
        XCTAssertFalse(settingsEntry.waitForExistence(timeout: 2), "Administration stays closed after a restart")

        // The state outlives the test, and the others expect Administration open.
        setAdministration(open: true)
    }

    // MARK: - On a sitemap

    // The menu is the same on every surface, and the sign-in is found out by the web view loading
    // Main UI behind whatever is shown, so Administration must behave the same on a sitemap.

    /// Picks the demo server's sitemap from the open menu and opens the menu again from the
    /// sitemap's own bar.
    private func showSitemapAndReopenMenu() {
        let sitemap = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Smart Home'")).firstMatch
        XCTAssertTrue(sitemap.waitForExistence(timeout: 20), "The demo sitemap is in the menu")
        sitemap.tap()
        XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 20), "The sitemap is on screen")
        let hamburger = app.buttons["HamburgerButton"]
        XCTAssertTrue(hamburger.waitForExistence(timeout: 8), "The sitemap has the menu button")
        hamburger.tap()
        XCTAssertTrue(header.waitForExistence(timeout: 8), "Administration is in the menu on a sitemap")
    }

    func testSitemapShowsASpinnerWhileNobodyHasSaid() {
        launch(server: signInServer, auth: pending)
        showSitemapAndReopenMenu()
        XCTAssertTrue(spinner.waitForExistence(timeout: 4))
        XCTAssertFalse(lock.exists)
        XCTAssertFalse(settingsEntry.exists)
    }

    func testSitemapOffersSigningInWhenNobodyHasSaidInTime() {
        launch(server: signInServer, timeout: 8)
        showSitemapAndReopenMenu()
        XCTAssertTrue(lock.waitForExistence(timeout: 12), "A page that never says ends up as a lock on a sitemap too")
    }

    func testSitemapShowsALockWhenSignedOut() {
        launch(server: signInServer, auth: signedOut, timeout: 600)
        showSitemapAndReopenMenu()
        XCTAssertTrue(lock.waitForExistence(timeout: 4))
        XCTAssertFalse(spinner.exists)
    }

    func testSitemapShowsTheEntriesToAnAdministrator() {
        launch(server: signInServer, auth: administrator, timeout: 600)
        showSitemapAndReopenMenu()
        XCTAssertTrue(settingsEntry.waitForExistence(timeout: 4))
        XCTAssertFalse(lock.exists)
        XCTAssertFalse(spinner.exists)
    }

    func testSitemapOpensEverythingOnAServerWithoutSignIn() {
        launch(server: openServer, timeout: 600)
        showSitemapAndReopenMenu()
        XCTAssertTrue(settingsEntry.waitForExistence(timeout: 4))
        XCTAssertFalse(spinner.exists)
    }
}
