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

@testable import openHAB
import Testing

@Suite("WebViewNavigationRouter")
struct WebViewNavigationRouterTests {
    // MARK: - route(for:)

    @Test("nil path routes to root")
    func nilPathRoutesToRoot() {
        #expect(WebViewNavigationRouter.route(for: nil) == .root)
    }

    @Test("server-side absolute path routes directly")
    func absolutePathRoutesDirectly() {
        #expect(WebViewNavigationRouter.route(for: "/some/path") == .path("/some/path"))
    }

    @Test("notification navigate:/page/… command routes directly")
    func navigatePageCommandRoutesDirectly() {
        #expect(WebViewNavigationRouter.route(for: "navigate:/page/my_page") == .path("/page/my_page"))
    }

    @Test("bare navigate: with no path falls back to live command")
    func bareNavigateFallsBackToLiveCommand() {
        #expect(WebViewNavigationRouter.route(for: "navigate:") == .liveCommand("navigate:"))
    }

    @Test("navigate: with a relative (non-\"/\") path falls back to live command")
    func navigateRelativePathFallsBackToLiveCommand() {
        #expect(WebViewNavigationRouter.route(for: "navigate:relative/path") == .liveCommand("navigate:relative/path"))
    }

    @Test("unrecognized raw command falls back to live command")
    func rawCommandFallsBackToLiveCommand() {
        #expect(WebViewNavigationRouter.route(for: "someRawCommand") == .liveCommand("someRawCommand"))
    }

    @Test("empty string falls back to live command, not root")
    func emptyPathFallsBackToLiveCommand() {
        #expect(WebViewNavigationRouter.route(for: "") == .liveCommand(""))
    }

    // MARK: - mainUIPath(fromNavigateCommand:)

    @Test("extracts the path from a navigate: command")
    func mainUIPathExtractsPath() {
        #expect(WebViewNavigationRouter.mainUIPath(fromNavigateCommand: "navigate:/page/x") == "/page/x")
    }

    @Test("nil for a command without the navigate: prefix")
    func mainUIPathNilWithoutPrefix() {
        #expect(WebViewNavigationRouter.mainUIPath(fromNavigateCommand: "foo:/page/x") == nil)
    }

    @Test("nil for navigate: with no path")
    func mainUIPathNilForBareNavigate() {
        #expect(WebViewNavigationRouter.mainUIPath(fromNavigateCommand: "navigate:") == nil)
    }

    @Test("nil for navigate: followed by a relative path")
    func mainUIPathNilForRelativePath() {
        #expect(WebViewNavigationRouter.mainUIPath(fromNavigateCommand: "navigate:relative") == nil)
    }
}
