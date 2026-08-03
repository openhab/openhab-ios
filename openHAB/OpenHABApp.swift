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

import SwiftUI

@main
struct OpenHABApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            OpenHABRootView()
            // TODO: DEVELOP MERGE (#1229) — develop's UIKit SceneDelegate handled the `openhab://` custom
            // URL scheme (deep links from notification actions), stripping the scheme and calling
            // notifyNotificationListeners(action:). That SceneDelegate was removed here because this app
            // uses the SwiftUI @main lifecycle (a UISceneDelegate + scene manifest conflicts with it).
            // Re-add that deep-link handling the SwiftUI way, e.g.:
            //   .onOpenURL { url in /* strip "openhab:" prefix -> notifyNotificationListeners(action:) */ }
            // (requires exposing AppDelegate.notificationDelegate or routing via NotificationCenter).
        }
    }
}
