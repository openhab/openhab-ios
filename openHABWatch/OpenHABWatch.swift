// Copyright (c) 2010-2023 Contributors to the openHAB project
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
struct OpenHABWatch: App {
    @ObservedObject var settings = ObservableOpenHABDataObject.shared
    // https://developer.apple.com/documentation/watchkit/wkapplicationdelegate
    @WKApplicationDelegateAdaptor(OpenHABWatchAppDelegate.self) var appDelegate
    @ObservedObject var userData = UserData(sitemapName: ObservableOpenHABDataObject.shared.sitemapName)

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView(viewModel: userData, settings: settings)
                    .tabItem {
                        Label("Received", systemImage: "tray.and.arrow.down.fill")
                    }
                PreferencesSwiftUIView()
                    .tabItem {
                        Label("Preferences", systemImage: "person.crop.circle.fill")
                    }
            }
            //            .environmentObject(userData)
        }

        #if os(watchOS)
        WKNotificationScene(controller: NotificationController.self, category: "openHABNotification")
        #endif
    }
}
