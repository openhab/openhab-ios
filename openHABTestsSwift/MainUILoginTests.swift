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

@Suite("MainUILogin")
struct MainUILoginTests {
    private let authorize = URL(string: "https://home.example.org/auth?response_type=code&client_id=https%3A%2F%2Fhome.example.org&scope=admin&state=abc")
    private let cloudAuthorize = URL(string: "https://myopenhab.org/proxy/abc/auth?response_type=code&state=x")

    // MARK: - The authorize page

    @Test("openHAB's authorize page is recognised, also behind a cloud connection's path")
    func authorizePage() {
        #expect(MainUILogin.isAuthorizePage(authorize))
        #expect(MainUILogin.isAuthorizePage(cloudAuthorize))
    }

    @Test("Other pages are not the authorize page")
    func otherPages() {
        #expect(!MainUILogin.isAuthorizePage(URL(string: "https://home.example.org/")))
        #expect(!MainUILogin.isAuthorizePage(URL(string: "https://home.example.org/profile/")))
        #expect(!MainUILogin.isAuthorizePage(URL(string: "https://home.example.org/auth")))
        #expect(!MainUILogin.isAuthorizePage(URL(string: "https://home.example.org/oauth?response_type=code")))
        #expect(!MainUILogin.isAuthorizePage(nil))
    }

    // MARK: - Cancel

    @Test("Cancel is the link to the server's root on the authorize page")
    func cancelLink() throws {
        let root = try #require(URL(string: "https://home.example.org/"))
        #expect(MainUILogin.isCancel(link: root, on: authorize))
    }

    @Test("On a cloud connection Cancel goes to the cloud's root, which is also caught")
    func cancelOnCloud() throws {
        let root = try #require(URL(string: "https://myopenhab.org/"))
        #expect(MainUILogin.isCancel(link: root, on: cloudAuthorize))
    }

    @Test("A link to the root from any other page is an ordinary link")
    func rootLinkElsewhere() throws {
        let root = try #require(URL(string: "https://home.example.org/"))
        #expect(!MainUILogin.isCancel(link: root, on: URL(string: "https://home.example.org/overview/")))
        #expect(!MainUILogin.isCancel(link: root, on: nil))
    }

    @Test("Other links on the authorize page are not Cancel")
    func otherLinksOnAuthorizePage() throws {
        #expect(try !MainUILogin.isCancel(link: #require(URL(string: "https://home.example.org/rest/")), on: authorize))
        #expect(try !MainUILogin.isCancel(link: #require(URL(string: "https://home.example.org/?code=1")), on: authorize))
        #expect(try !MainUILogin.isCancel(link: #require(URL(string: "https://other.example.org/")), on: authorize))
        #expect(try !MainUILogin.isCancel(link: #require(URL(string: "https://home.example.org:8443/")), on: authorize))
    }

    // MARK: - The way back

    @Test("Back is the route Main UI was on when the sign-in began")
    func routeBeforeLogin() {
        #expect(MainUILogin.routeBeforeLogin(path: "/page/kitchen/", history: ["/", "/page/kitchen/"]) == "/page/kitchen/")
    }

    @Test("The sign-in starts from the profile, so back is the page before the profile")
    func routeBeforeProfile() {
        #expect(MainUILogin.routeBeforeLogin(path: "/profile/", history: ["/", "/page/kitchen/", "/profile/"]) == "/page/kitchen/")
    }

    @Test("Back skips a profile that is in the history more than once")
    func profileTwiceInHistory() {
        let history = ["/", "/settings/", "/profile/", "/profile/"]
        #expect(MainUILogin.routeBeforeLogin(path: "/profile/", history: history) == "/settings/")
    }

    @Test("Without a page before the profile, back is Main UI's front page")
    func profileOnly() {
        #expect(MainUILogin.routeBeforeLogin(path: "/profile/", history: ["/profile/"]) == "/")
        #expect(MainUILogin.routeBeforeLogin(path: "/profile/", history: []) == "/")
    }

    @Test("Without any page reported, back is Main UI's front page")
    func nothingReported() {
        #expect(MainUILogin.routeBeforeLogin(path: nil, history: []) == "/")
    }

    // MARK: - The way back, by what the user was looking at

    @Test("From Main UI, back is Main UI at the route it was on")
    func wayBackFromMainUI() {
        #expect(MainUILogin.wayBack(from: .mainUIPage("/page/kitchen/"), route: "/page/kitchen/") == .mainUI(path: "/page/kitchen/"))
        #expect(MainUILogin.wayBack(from: .webview, route: "/overview/") == .mainUI(path: "/overview/"))
    }

    @Test("From Main UI's front page, back is the front page")
    func wayBackToFrontPage() {
        #expect(MainUILogin.wayBack(from: .webview, route: "/") == .mainUI(path: nil))
    }

    @Test("From a sitemap, back is the sitemap, with Main UI loaded behind it at its route")
    func wayBackFromSitemap() {
        let sitemap = TargetController.sitemap("home")
        #expect(MainUILogin.wayBack(from: sitemap, route: "/page/kitchen/") == .sitemap(sitemap, mainUIRoute: "/page/kitchen/"))
        #expect(MainUILogin.wayBack(from: sitemap, route: "/") == .sitemap(sitemap, mainUIRoute: "/"))
    }

    @Test("From a tile, back is the tile")
    func wayBackFromTile() {
        #expect(MainUILogin.wayBack(from: .tile("https://example.org/tile"), route: "/page/x/") == .tile(url: "https://example.org/tile"))
    }

    @Test("When it is not known what was showing, back is Main UI")
    func wayBackWithoutPrevious() {
        #expect(MainUILogin.wayBack(from: nil, route: "/page/x/") == .mainUI(path: "/page/x/"))
        #expect(MainUILogin.wayBack(from: nil, route: "/") == .mainUI(path: nil))
    }
}
