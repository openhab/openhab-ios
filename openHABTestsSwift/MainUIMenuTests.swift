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
import OpenHABCore
import Testing

@Suite("MainUIMenu")
struct MainUIMenuTests {
    private let signInServer = MainUIServer(majorVersion: 5, endpoints: ["auth", "items", "things", "rules", "ui", "addons"])
    private let ann = OHBridgeUser(name: "ann", roles: ["user"])
    private let admin = OHBridgeUser(name: "root", roles: ["administrator"])

    private func page(_ uid: String, visibleTo: [String] = []) -> OpenHABUIPage {
        OpenHABUIPage(uid: uid, label: uid, icon: "", order: 1000, url: "/page/\(uid)", visibleTo: visibleTo)
    }

    // MARK: - Access

    @Test("Nothing is known until the server's endpoints are")
    func unknownWithoutServer() {
        #expect(MainUIAccess(server: nil, auth: nil) == nil)
    }

    @Test("A server without the auth endpoint has no sign-in, so everybody is an administrator")
    func openWithoutAuthEndpoint() {
        let server = MainUIServer(majorVersion: 4, endpoints: ["items"])
        let access = MainUIAccess(server: server, auth: nil)
        #expect(access == .open)
        #expect(access?.isAdministrator == true)
    }

    @Test("Until a page says who is signed in, the user counts as signed out")
    func signedOutWithoutAuthState() {
        #expect(MainUIAccess(server: signInServer, auth: nil) == .signedOut)
        #expect(MainUIAccess(server: signInServer, auth: OHBridgeAuthState(user: nil, noAuth: false)) == .signedOut)
        #expect(MainUIAccess(server: signInServer, auth: nil)?.isAdministrator == false)
    }

    @Test("Only the administrator role makes an administrator")
    func administratorRole() {
        #expect(MainUIAccess(server: signInServer, auth: OHBridgeAuthState(user: ann, noAuth: false))?.isAdministrator == false)
        #expect(MainUIAccess(server: signInServer, auth: OHBridgeAuthState(user: admin, noAuth: false))?.isAdministrator == true)
    }

    @Test("A page that says there is no sign-in opens everything")
    func noAuthFromPage() {
        #expect(MainUIAccess(server: signInServer, auth: OHBridgeAuthState(user: nil, noAuth: true)) == .open)
    }

    // MARK: - Pinned pages

    @Test("Pages limited by visibleTo stay hidden while signed out")
    func limitedPagesHiddenSignedOut() {
        let pages = [page("all"), page("members", visibleTo: ["role:user"])]
        #expect(MainUIMenu.pinnedPages(pages, access: .signedOut).map(\.uid) == ["all"])
        #expect(MainUIMenu.pinnedPages(pages, access: nil).map(\.uid) == ["all"])
    }

    @Test("A signed-in user sees the pages limited to their role or name")
    func limitedPagesForSignedIn() {
        let pages = [
            page("all"),
            page("members", visibleTo: ["role:user", "role:guest"]),
            page("ann", visibleTo: ["user:ann"]),
            page("admins", visibleTo: ["role:administrator"])
        ]
        #expect(MainUIMenu.pinnedPages(pages, access: .signedIn(ann)).map(\.uid) == ["all", "members", "ann"])
        #expect(MainUIMenu.pinnedPages(pages, access: .signedIn(admin)).map(\.uid) == ["all", "admins"])
    }

    @Test("Without sign-in every pinned page shows")
    func limitedPagesWhenOpen() {
        let pages = [page("all"), page("members", visibleTo: ["role:user"])]
        #expect(MainUIMenu.pinnedPages(pages, access: .open).map(\.uid) == ["all", "members"])
    }

    // MARK: - Entries

    @Test("Chat is there from openHAB 5")
    func chatFromFive() {
        #expect(MainUIMenu.chatEntry(server: signInServer)?.path == "/chat/")
        #expect(MainUIMenu.chatEntry(server: MainUIServer(majorVersion: 4, endpoints: [])) == nil)
        #expect(MainUIMenu.chatEntry(server: nil) == nil)
    }

    @Test("Administration lists each entry whose endpoints the server offers, with Main UI's trailing slashes")
    func administrationEntries() {
        #expect(MainUIMenu.administrationEntries(server: signInServer).map(\.path) == ["/settings/", "/addons/", "/developer/"])
        let minimal = MainUIServer(majorVersion: 4, endpoints: ["rules"])
        #expect(MainUIMenu.administrationEntries(server: minimal).map(\.path) == ["/settings/"])
        #expect(MainUIMenu.administrationEntries(server: MainUIServer(majorVersion: 4, endpoints: [])).isEmpty)
    }

    @Test("Help & About opens Main UI's about page")
    func about() {
        #expect(MainUIMenu.aboutEntry.path == "/about/")
    }

    @Test("A server's root resource lists its endpoints as links")
    func endpointsFromRoot() throws {
        let json = #"{"version":"4.3.0","links":[{"type":"items","url":"http://h/rest/items"},{"type":"auth","url":"http://h/rest/auth"}]}"#
        let server = try MainUIServer(JSONDecoder().decode(OpenHABServerProperties.self, from: Data(json.utf8)))
        #expect(server.majorVersion == 4)
        #expect(server.endpoints == ["items", "auth"])
        #expect(!server.hasChat)
    }
}
