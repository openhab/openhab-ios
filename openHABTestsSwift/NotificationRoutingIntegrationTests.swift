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

/// Joins the three layers that individually have their own test coverage
/// (`NotificationCommandParser`, `NotificationActionService`, `WebViewNavigationRouter`)
/// so a regression in how they compose — like openhab-ios#1336, where a correctly parsed
/// "ui:navigate:/page/…" action still failed to land because the routing step didn't
/// recognize it — would be caught here even if each layer's own tests still pass.
@Suite("Notification routing pipeline")
@MainActor
struct NotificationRoutingIntegrationTests {
    @Test("ui:navigate:/page/… loads the target path directly when Main UI isn't already shown")
    func navigatePageCommandLoadsDirectlyOnColdMainUI() throws {
        // 1. NotificationCommandParser parses the raw onClickAction.
        let parsed = NotificationCommandParser.parse("ui:navigate:/page/my_page")
        #expect(parsed == .ui(.webViewCommand("navigate:/page/my_page")))

        // 2. NotificationActionService turns that into a NavigationCommand.
        let svc = NotificationActionService(autoStart: false)
        svc.handleNotificationInternal("ui:navigate:/page/my_page")
        #expect(svc.navigationCommand == .switchToWebView(path: "navigate:/page/my_page"))

        // 3. On a cold launch (Main UI not already shown), the coordinator must resolve
        // this to loading the target path directly — not queuing it as a live command,
        // which is what left the user on the Overview page in #1336.
        let navigationCommand = try #require(svc.navigationCommand)
        let action = NavigationCommandCoordinator.action(for: navigationCommand, isMainUIShown: false)
        #expect(action == .showMainUI(path: "/page/my_page"))
    }

    @Test("ui:navigate:/page/… routes client-side when Main UI is already shown")
    func navigatePageCommandRoutesDirectlyWhenMainUIAlreadyShown() throws {
        let svc = NotificationActionService(autoStart: false)
        svc.handleNotificationInternal("ui:navigate:/page/my_page")

        let navigationCommand = try #require(svc.navigationCommand)
        let action = NavigationCommandCoordinator.action(for: navigationCommand, isMainUIShown: true)
        // Same resolved path either way — showMainUI(path:) itself decides whether to
        // reload the SPA or route client-side depending on whether it's already live.
        #expect(action == .showMainUI(path: "/page/my_page"))
    }

    @Test("ui:/some/path (explicit server-side path) also loads directly")
    func absoluteServerPathLoadsDirectly() throws {
        let svc = NotificationActionService(autoStart: false)
        svc.handleNotificationInternal("ui:/some/path")

        let navigationCommand = try #require(svc.navigationCommand)
        let action = NavigationCommandCoordinator.action(for: navigationCommand, isMainUIShown: false)
        #expect(action == .showMainUI(path: "/some/path"))
    }

    @Test("ui:/basicui/app?sitemap=… resolves to a sitemap switch, not a web view route")
    func sitemapCommandRoutesToSitemapAction() throws {
        let svc = NotificationActionService(autoStart: false)
        svc.handleNotificationInternal("ui:/basicui/app?sitemap=demo&w=0001")

        let navigationCommand = try #require(svc.navigationCommand)
        let action = NavigationCommandCoordinator.action(for: navigationCommand, isMainUIShown: false)
        #expect(action == .switchToSitemap(name: "demo", widgetId: "0001"))
    }
}
