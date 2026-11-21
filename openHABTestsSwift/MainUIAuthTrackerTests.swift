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

import Foundation
@testable import openHAB
import Testing

@Suite("MainUIAuthTracker")
struct MainUIAuthTrackerTests {
    private let home = UUID()
    private let otherHome = UUID()
    private let local = URL(string: "http://openhab.local:8080/")
    private let remote = URL(string: "https://home.example.org/")
    private let cloud = URL(string: "https://myopenhab.org/")

    private let signedInAnn = OHBridgeAuthState(user: OHBridgeUser(name: "ann", roles: ["user"]), noAuth: false)
    private let signedInRoot = OHBridgeAuthState(user: OHBridgeUser(name: "root", roles: ["administrator"]), noAuth: false)
    private let signedOut = OHBridgeAuthState(user: nil, noAuth: false)
    private let noAuth = OHBridgeAuthState(user: nil, noAuth: true)
    private let signInServer = MainUIServer(majorVersion: 5, endpoints: ["auth", "items", "ui"])

    private func key(_ url: URL?, home: UUID? = nil) -> MainUIAuthKey {
        MainUIAuthKey(home: home ?? self.home, url: url)!
    }

    private func tracker(active url: URL?) -> MainUIAuthTracker {
        var tracker = MainUIAuthTracker()
        tracker.activate(key(url))
        return tracker
    }

    // MARK: - Keys

    @Test("An origin is scheme, host and port, whatever the path, case or spelled-out default port")
    func originNormalisation() {
        let plain = MainUIAuthKey(home: home, url: URL(string: "https://Home.Example.org/overview/"))
        let withPort = MainUIAuthKey(home: home, url: URL(string: "https://home.example.org:443/auth?x=1"))
        #expect(plain == withPort)
        #expect(plain?.origin == "https://home.example.org:443")
        #expect(MainUIAuthKey(home: home, url: URL(string: "http://h/"))?.origin == "http://h:80")
    }

    @Test("Another scheme, host or port is another origin")
    func originsDiffer() {
        #expect(key(URL(string: "http://h:8080/")) != key(URL(string: "http://h:8081/")))
        #expect(key(URL(string: "http://h/")) != key(URL(string: "https://h/")))
        #expect(key(local) != key(remote))
    }

    @Test("A page that is no web address has no origin")
    func noOrigin() {
        #expect(MainUIAuthKey(home: home, url: URL(string: "about:blank")) == nil)
        #expect(MainUIAuthKey(home: home, url: nil) == nil)
    }

    // MARK: - Before anybody has said

    @Test("Nothing is known before a page has reported, which is not the same as signed out")
    func unknownAtFirst() {
        #expect(MainUIAuthTracker().status == .unknown)
        #expect(tracker(active: local).status == .unknown)
    }

    @Test("Without a connection nothing is known")
    func noConnection() {
        var tracker = tracker(active: local)
        tracker.report(signedInRoot, from: key(local))
        tracker.activate(nil)
        #expect(tracker.status == .unknown)
    }

    // MARK: - Happy paths

    @Test("What the page reports for the active origin is what shows")
    func reportForActiveOrigin() {
        var tracker = tracker(active: local)
        tracker.report(signedInRoot, from: key(local))
        #expect(tracker.status == .known(signedInRoot))
    }

    @Test("Signing out in the page replaces the sign-in")
    func signOutInPage() {
        var tracker = tracker(active: local)
        tracker.report(signedInRoot, from: key(local))
        tracker.report(signedOut, from: key(local))
        #expect(tracker.status == .known(signedOut))
    }

    @Test("Signing in as somebody else in the page replaces the user")
    func otherUserInPage() {
        var tracker = tracker(active: local)
        tracker.report(signedInAnn, from: key(local))
        tracker.report(signedInRoot, from: key(local))
        #expect(tracker.status == .known(signedInRoot))
    }

    @Test("A server without sign-in is reported as it is")
    func noAuthServer() {
        var tracker = tracker(active: local)
        tracker.report(noAuth, from: key(local))
        #expect(tracker.status == .known(noAuth))
    }

    @Test("Each origin keeps its own sign-in when switching back and forth")
    func switchingKeepsEachOrigin() {
        var tracker = tracker(active: local)
        tracker.report(signedInRoot, from: key(local))
        tracker.activate(key(remote))
        tracker.report(signedInAnn, from: key(remote))
        #expect(tracker.status == .known(signedInAnn))
        tracker.activate(key(local))
        #expect(tracker.status == .known(signedInRoot))
        tracker.activate(key(remote))
        #expect(tracker.status == .known(signedInAnn))
    }

    @Test("Signed in on one origin and signed out on the other")
    func signedInOnOneOnly() {
        var tracker = tracker(active: local)
        tracker.report(signedInRoot, from: key(local))
        tracker.activate(key(remote))
        tracker.report(signedOut, from: key(remote))
        #expect(tracker.status == .known(signedOut))
        tracker.activate(key(local))
        #expect(tracker.status == .known(signedInRoot))
    }

    @Test("A cloud connection is an origin of its own")
    func cloudOrigin() {
        var tracker = tracker(active: remote)
        tracker.report(signedInRoot, from: key(remote))
        tracker.activate(key(cloud))
        #expect(tracker.status == .unknown)
    }

    // MARK: - Gaps

    @Test("After a switch the old origin's sign-in is not shown for the new one")
    func staleStateAfterSwitch() {
        var tracker = tracker(active: local)
        tracker.report(signedInRoot, from: key(local))
        tracker.activate(key(remote))
        #expect(tracker.status == .unknown)
    }

    @Test("A late report from the origin that was left does not become the new origin's")
    func lateReportFromSupersededOrigin() {
        var tracker = tracker(active: local)
        tracker.activate(key(remote))
        tracker.report(signedInRoot, from: key(local))
        #expect(tracker.status == .unknown)
        tracker.activate(key(local))
        #expect(tracker.status == .known(signedInRoot))
    }

    @Test("Another home's sign-in on the same address does not leak")
    func homesAreSeparate() {
        var tracker = tracker(active: local)
        tracker.report(signedInRoot, from: key(local))
        tracker.activate(key(local, home: otherHome))
        #expect(tracker.status == .unknown)
        tracker.activate(key(local))
        #expect(tracker.status == .known(signedInRoot))
    }

    @Test("A page that never reports ends up as given up, not as unknown for ever")
    func givesUp() {
        var tracker = tracker(active: local)
        tracker.giveUp()
        #expect(tracker.status == .gaveUp)
    }

    @Test("Giving up leaves a sign-in that is known alone")
    func givingUpKeepsKnown() {
        var tracker = tracker(active: local)
        tracker.report(signedInRoot, from: key(local))
        tracker.giveUp()
        #expect(tracker.status == .known(signedInRoot))
    }

    @Test("Giving up concerns the active origin only")
    func givingUpIsPerOrigin() {
        var tracker = tracker(active: local)
        tracker.giveUp()
        tracker.activate(key(remote))
        #expect(tracker.status == .unknown)
    }

    @Test("A report after giving up still wins")
    func reportAfterGivingUp() {
        var tracker = tracker(active: local)
        tracker.giveUp()
        tracker.report(signedInRoot, from: key(local))
        #expect(tracker.status == .known(signedInRoot))
    }

    @Test("Giving up without an active origin does nothing")
    func givingUpWithoutOrigin() {
        var tracker = MainUIAuthTracker()
        tracker.giveUp()
        #expect(tracker.status == .unknown)
    }

    @Test("A new load of an origin that gave up is waited for again")
    func waitingAgainAfterGivingUp() {
        var tracker = tracker(active: local)
        tracker.giveUp()
        tracker.startWaiting()
        #expect(tracker.status == .unknown)
    }

    @Test("A new load does not forget a sign-in that is known")
    func waitingKeepsKnown() {
        var tracker = tracker(active: local)
        tracker.report(signedInRoot, from: key(local))
        tracker.startWaiting()
        #expect(tracker.status == .known(signedInRoot))
    }

    // MARK: - What the menu makes of it

    @Test("Unknown is resolving, which offers no sign-in and shows no administration")
    func resolvingAccess() {
        let access = MainUIAccess(server: signInServer, status: .unknown)
        #expect(access == .resolving)
        #expect(access?.isAdministrator == false)
        #expect(access?.canSee(visibleTo: ["role:user"]) == false)
        #expect(access?.canSee(visibleTo: []) == true)
    }

    @Test("Giving up is signed out, which offers to sign in")
    func gaveUpAccess() {
        #expect(MainUIAccess(server: signInServer, status: .gaveUp) == .signedOut)
    }

    @Test("Known states map to their access")
    func knownAccess() {
        #expect(MainUIAccess(server: signInServer, status: .known(signedInRoot))?.isAdministrator == true)
        #expect(MainUIAccess(server: signInServer, status: .known(signedInAnn))?.isAdministrator == false)
        #expect(MainUIAccess(server: signInServer, status: .known(signedOut)) == .signedOut)
        #expect(MainUIAccess(server: signInServer, status: .known(noAuth)) == .open)
    }

    @Test("A server without sign-in is open even while the page has not said")
    func openServerNeverResolves() {
        let open = MainUIServer(majorVersion: 4, endpoints: ["items"])
        #expect(MainUIAccess(server: open, status: .unknown) == .open)
    }

    @Test("Nothing is shown before the server's endpoints are known")
    func noServerNoAccess() {
        #expect(MainUIAccess(server: nil, status: .unknown) == nil)
    }
}
