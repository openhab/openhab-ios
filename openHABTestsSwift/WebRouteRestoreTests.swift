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
@testable import OpenHABCore
import Testing

@Suite("WebRouteRestore")
struct WebRouteRestoreTests {
    private static let local = "http://openhab.local:8080"

    private static let deep = #"{"deep":true}"#

    private func snapshot(_ history: [String],
                          props: [String]? = nil,
                          connectionURL: String = local,
                          capturedAt: Date = Date()) -> WebRouteSnapshot {
        WebRouteSnapshot(
            history: history,
            props: props,
            url: history.last ?? "",
            connectionURL: connectionURL,
            capturedAt: capturedAt
        )
    }

    // MARK: - Payload decoding

    @Test("Decodes the payload posted by the injected script")
    func decodesPayload() {
        let json = #"{"history":["/overview/","/page/kitchen"],"url":"/page/kitchen"}"#
        let decoded = WebRouteRestore.snapshot(fromJSON: json, connectionURL: Self.local)
        #expect(decoded?.history == ["/overview/", "/page/kitchen"])
        #expect(decoded?.url == "/page/kitchen")
        #expect(decoded?.connectionURL == Self.local)
    }

    @Test("Decodes the props posted with each page")
    func decodesProps() {
        let json = #"{"history":["/overview/","/page/kitchen"],"props":["{}","{\"deep\":true}"],"url":"/page/kitchen"}"#
        let decoded = WebRouteRestore.snapshot(fromJSON: json, connectionURL: Self.local)
        #expect(decoded?.props == ["{}", Self.deep])
    }

    @Test("Props that do not line up with the pages are dropped")
    func dropsMisalignedProps() {
        let json = #"{"history":["/overview/","/page/kitchen"],"props":["{}"],"url":"/page/kitchen"}"#
        let decoded = WebRouteRestore.snapshot(fromJSON: json, connectionURL: Self.local)
        #expect(decoded?.history == ["/overview/", "/page/kitchen"])
        #expect(decoded?.props == nil)
    }

    @Test("A snapshot saved before props were kept still decodes")
    func decodesSnapshotWithoutProps() throws {
        let json = #"{"history":["/overview/"],"url":"/overview/","connectionURL":"http://a","capturedAt":0}"#
        let decoded = try JSONDecoder().decode(WebRouteSnapshot.self, from: Data(json.utf8))
        #expect(decoded.history == ["/overview/"])
        #expect(decoded.props == nil)
    }

    @Test("Rejects an empty or malformed payload")
    func rejectsBadPayload() {
        #expect(WebRouteRestore.snapshot(fromJSON: "not json", connectionURL: Self.local) == nil)
        #expect(WebRouteRestore.snapshot(fromJSON: #"{"history":[],"url":""}"#, connectionURL: Self.local) == nil)
        #expect(WebRouteRestore.snapshot(fromJSON: #"{"url":"/page/a"}"#, connectionURL: Self.local) == nil)
    }

    // MARK: - Restore eligibility

    @Test("Restores on an automatic load of the Main UI")
    func restoresOnAutomaticLoad() {
        let stored = snapshot(["/overview/", "/page/kitchen"])
        let result = WebRouteRestore.snapshotToRestore(stored, for: .init(
            path: nil, force: false, isShowingTile: false
        ))
        #expect(result == stored)
    }

    @Test("An explicit path, a forced reload, or a tile suppresses the restore")
    func suppressedByDeliberateDestinations() {
        let stored = snapshot(["/overview/", "/page/kitchen"])
        #expect(WebRouteRestore.snapshotToRestore(stored, for: .init(
            path: "/page/other", force: false, isShowingTile: false
        )) == nil)
        #expect(WebRouteRestore.snapshotToRestore(stored, for: .init(
            path: nil, force: true, isShowingTile: false
        )) == nil)
        #expect(WebRouteRestore.snapshotToRestore(stored, for: .init(
            path: nil, force: false, isShowingTile: true
        )) == nil)
    }

    @Test("Nothing stored means nothing to restore")
    func noStoredSnapshot() {
        #expect(WebRouteRestore.snapshotToRestore(nil, for: .init(
            path: nil, force: false, isShowingTile: false
        )) == nil)
    }

    // MARK: - Seeding

    @Test("Seeds the stack verbatim when staying on the same connection")
    func seedsVerbatim() {
        let seed = WebRouteRestore.seed(for: snapshot(["/overview/", "/settings/things/", "/page/kitchen"]), dropAdmin: false)
        #expect(seed?.history == ["/overview/", "/settings/things/", "/page/kitchen"])
        #expect(seed?.url == "/page/kitchen")
    }

    @Test("Each page keeps its own props")
    func seedsProps() {
        let stored = snapshot(["/overview/", "/page/kitchen"], props: ["{}", Self.deep])
        let seed = WebRouteRestore.seed(for: stored, dropAdmin: false)
        #expect(seed?.props == ["{}", Self.deep])
    }

    @Test("Pages saved without props get empty ones")
    func seedsEmptyPropsWhenMissing() {
        let seed = WebRouteRestore.seed(for: snapshot(["/overview/", "/page/kitchen"]), dropAdmin: false)
        #expect(seed?.props == [WebRouteRestore.noProps, WebRouteRestore.noProps])
    }

    @Test("Props stay with their page when admin routes are dropped")
    func propsFollowAdminDrop() {
        let stored = snapshot(
            ["/overview/", "/settings/things/", "/page/kitchen"],
            props: ["{}", #"{"deep":false}"#, Self.deep]
        )
        let seed = WebRouteRestore.seed(for: stored, dropAdmin: true)
        #expect(seed?.history == ["/overview/", "/page/kitchen"])
        #expect(seed?.props == ["{}", Self.deep])
    }

    @Test("When repeats collapse, the page keeps how it was last opened")
    func collapsedRepeatKeepsLaterProps() {
        let stored = snapshot(
            ["/overview/", "/page/a", "/settings/", "/page/a", "/page/b"],
            props: ["{}", "{}", "{}", Self.deep, Self.deep]
        )
        let seed = WebRouteRestore.seed(for: stored, dropAdmin: true)
        #expect(seed?.history == ["/overview/", "/page/a", "/page/b"])
        #expect(seed?.props == ["{}", Self.deep, Self.deep])
    }

    @Test("Capping a long stack keeps props lined up")
    func capKeepsPropsAligned() {
        let long = (0 ..< 50).map { "/page/p\($0)" }
        let props = (0 ..< 50).map { #"{"defineVars":{"n":\#($0)}}"# }
        let seed = WebRouteRestore.seed(for: snapshot(long, props: props), dropAdmin: false)
        #expect(seed?.props.count == WebRouteRestore.maxSeededEntries)
        #expect(seed?.props.last == #"{"defineVars":{"n":49}}"#)
        #expect(seed?.props.first == #"{"defineVars":{"n":\#(50 - WebRouteRestore.maxSeededEntries)}}"#)
    }

    @Test("Drops guarded admin routes when moving to another connection")
    func dropsAdminRoutes() {
        let stored = snapshot(["/overview/", "/settings/things/", "/settings/things/inbox", "/developer/widgets/", "/page/kitchen"])
        let seed = WebRouteRestore.seed(for: stored, dropAdmin: true)
        #expect(seed?.history == ["/overview/", "/page/kitchen"])
        #expect(seed?.url == "/page/kitchen")
    }

    @Test("Dropping admin routes re-targets the entry URL")
    func dropsAdminEntryURL() {
        let stored = snapshot(["/overview/", "/page/kitchen", "/settings/things/"])
        let seed = WebRouteRestore.seed(for: stored, dropAdmin: true)
        #expect(seed?.history == ["/overview/", "/page/kitchen"])
        #expect(seed?.url == "/page/kitchen")
    }

    @Test("A stack of nothing but admin routes is not restored at all")
    func allAdminYieldsNothing() {
        #expect(WebRouteRestore.seed(for: snapshot(["/settings/", "/settings/things/"]), dropAdmin: true) == nil)
    }

    @Test("Collapses repeats left behind by dropped entries")
    func collapsesRepeats() {
        let stored = snapshot(["/overview/", "/settings/", "/overview/", "/page/kitchen"])
        let seed = WebRouteRestore.seed(for: stored, dropAdmin: true)
        #expect(seed?.history == ["/overview/", "/page/kitchen"])
    }

    /// Going back and forth between two pages, then dropping the earlier copy of the current
    /// one, leaves the other page next to itself. It would take two presses of back to leave it.
    @Test("Collapses repeats left behind by removing earlier copies of the current page")
    func collapsesRepeatsAfterRemovingCopies() {
        let seed = WebRouteRestore.seed(for: snapshot(["/page/a", "/page/b", "/page/a", "/page/b"]), dropAdmin: false)
        #expect(seed?.history == ["/page/a", "/page/b"])
        #expect(seed?.url == "/page/b")
    }

    /// We add one browser history entry per page, and iOS stops accepting them after a while.
    @Test("A long stack is capped to the most recent entries")
    func capsLongStack() {
        let long = (0 ..< 200).map { "/page/p\($0)" }
        let seed = WebRouteRestore.seed(for: snapshot(long), dropAdmin: false)
        #expect(seed?.history.count == WebRouteRestore.maxSeededEntries)
        #expect(seed?.history.last == "/page/p199")
        #expect(seed?.url == "/page/p199")
        // The newest are kept, so the oldest go.
        #expect(seed?.history.first == "/page/p\(200 - WebRouteRestore.maxSeededEntries)")
    }

    @Test("Earlier copies of the entry URL are removed so Framework7 cannot truncate the stack")
    func entryURLIsUnique() {
        let stored = snapshot(["/page/kitchen", "/overview/", "/page/lights", "/page/kitchen"])
        let seed = WebRouteRestore.seed(for: stored, dropAdmin: false)
        #expect(seed?.history == ["/overview/", "/page/lights", "/page/kitchen"])
        #expect(seed?.url == "/page/kitchen")
    }

    @Test("Admin matching is by path segment, not bare prefix", arguments: [
        ("/settings", true),
        ("/settings/", true),
        ("/settings/things/inbox", true),
        ("/developer/widgets/", true),
        ("/addons/", true),
        ("/setup-wizard", true),
        ("/settings-of-mine/", false),
        ("/page/settings", false),
        ("/overview/", false)
    ])
    func adminPathMatching(path: String, isAdmin: Bool) {
        #expect(WebRouteRestore.isAdminPath(path) == isAdmin)
    }

    @Test("Admin matching ignores the query string")
    func adminPathIgnoresQuery() {
        #expect(WebRouteRestore.isAdminPath("/settings/things/?tab=1"))
    }

    // MARK: - Script generation

    @Test("A nil restore leaves whatever Framework7 itself persisted")
    func nilRestoreEmitsNull() {
        let source = webViewRouteRestoreJS(restore: nil)
        #expect(source.contains("var RESTORE = null"))
    }

    @Test("Props are emitted as a JSON array of strings, parsed in the page")
    func propsEmittedAsStrings() {
        let source = webViewRouteRestoreJS(restore: ["/overview/", "/page/kitchen"], props: ["{}", Self.deep])
        #expect(source.contains(#"var RESTORE_PROPS = ["{}","{\"deep\":true}"]"#))
        #expect(webViewRouteRestoreJS(restore: nil).contains("var RESTORE_PROPS = null"))
    }

    /// The Main UI opens a restored page from its address alone, which carries no props.
    @Test("The script hands the props back to Framework7 and reopens the current page with its own")
    func scriptRestoresProps() {
        let source = webViewRouteRestoreJS(restore: ["/overview/", "/page/kitchen"], props: ["{}", Self.deep])
        #expect(source.contains("r.propsHistory = list"))
        #expect(source.contains("reloadCurrent: true, animate: false, browserHistory: false, props: top"))
        #expect(source.contains("if (restoring) whenRestoredPageOpen()"))
    }

    @Test("Only the props that survive being saved are captured")
    func scriptKeepsOnlyKnownProps() {
        let source = webViewRouteRestoreJS(restore: nil)
        #expect(source.contains("var KEPT_PROPS = ['deep', 'defineVars']"))
        #expect(source.contains("return { history: stack, props: props, url: stack[stack.length - 1] }"))
    }

    /// Framework7 adds a popup to its history without props, then removes the last props
    /// when it closes, which would take the page underneath's back link with it.
    @Test("Open popups get stand-in props so the page underneath keeps its own")
    func scriptPadsPopupProps() {
        let source = webViewRouteRestoreJS(restore: nil)
        #expect(source.contains("padPopupProps(r)"))
        #expect(source.contains("r.propsHistory.push(POPUP_PROPS)"))
    }

    @Test("A restore payload is emitted as a JSON array")
    func restoreEmitsJSONArray() {
        let source = webViewRouteRestoreJS(restore: ["/overview/", "/page/kitchen"])
        #expect(source.contains(#"var RESTORE = ["/overview/","/page/kitchen"]"#))
        #expect(source.contains("'f7router-' + VIEW_ID + '-history'"))
    }

    /// The Main UI remembers the pages itself, but going back is really the browser going
    /// back, and a page that just opened has nothing behind it.
    @Test("The script seeds the browser session history as well as Framework7's stack")
    func seedsBrowserHistory() {
        let source = webViewRouteRestoreJS(restore: ["/overview/", "/page/kitchen"])
        #expect(source.contains("seedBrowserHistory(RESTORE)"))
        #expect(source.contains("history.replaceState(stateFor(stack[0]), '', BASE + stack[0])"))
        #expect(source.contains("history.pushState(stateFor(stack[i]), '', BASE + stack[i])"))
        #expect(source.contains("state[VIEW_ID] = { url: url }"))
    }

    /// We ask for the app's front page, so the page addresses have to add back whatever the
    /// app sits under, or they would point outside it.
    @Test("The base path is emitted as a JS string literal")
    func basePathIsEmitted() {
        #expect(webViewRouteRestoreJS(restore: ["/overview/"]).contains(#"var BASE = """#))
        #expect(webViewRouteRestoreJS(restore: ["/overview/"], basePath: "/oh").contains(#"var BASE = "/oh""#))
    }

    /// The same scripts run for every page the app opens, so without this a tile could get
    /// dragged off to the wrong page.
    @Test("Seeding is gated on the document being the app root")
    func seedingIsGatedOnAppRoot() {
        let source = webViewRouteRestoreJS(restore: ["/overview/", "/page/kitchen"])
        #expect(source.contains("RESTORE && RESTORE.length && isAppRoot()"))
        #expect(source.contains("return path === BASE || path === BASE + '/'"))
    }

    // MARK: - Snapshot freshness

    @Test("A snapshot older than the maximum age is stale")
    func staleSnapshot() {
        let now = Date()
        let fresh = snapshot(["/overview/"], capturedAt: now.addingTimeInterval(-60))
        let stale = snapshot(["/overview/"], capturedAt: now.addingTimeInterval(-WebRouteSnapshot.maxAge - 1))
        #expect(fresh.isFresh(now: now))
        #expect(!stale.isFresh(now: now))
    }

    @Test("A stack is remembered for a week")
    func maxAgeIsOneWeek() {
        #expect(WebRouteSnapshot.maxAge == 7 * 24 * 60 * 60)
        let now = Date()
        let sixDays = snapshot(["/overview/"], capturedAt: now.addingTimeInterval(-6 * 24 * 60 * 60))
        let eightDays = snapshot(["/overview/"], capturedAt: now.addingTimeInterval(-8 * 24 * 60 * 60))
        #expect(sixDays.isFresh(now: now))
        #expect(!eightDays.isFresh(now: now))
    }

    @Test("A snapshot from the future is treated as stale")
    func futureSnapshot() {
        let now = Date()
        #expect(!snapshot(["/overview/"], capturedAt: now.addingTimeInterval(600)).isFresh(now: now))
    }
}
