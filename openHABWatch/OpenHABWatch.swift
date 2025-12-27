// Copyright (c) 2010-2025 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Kingfisher
import OpenHABCore
import SFSafeSymbols
import SwiftUI
import UserNotifications

@main
struct OpenHABWatch: App {
    @ObservedObject var settings = AppSettings.shared
    // https://developer.apple.com/documentation/watchkit/wkapplicationdelegate
    @WKApplicationDelegateAdaptor var appDelegate: OpenHABWatchAppDelegate
    @ObservedObject var userData = UserData.shared

    var body: some Scene {
        WindowGroup {
            TabView {
                SitemapPageView(viewModel: userData)
                    .tabItem {
                        Label("Sitemap", systemSymbol: .circleFill)
                    }
                PreferencesSwiftUIView()
                    .tabItem {
                        Label("Preferences", systemSymbol: .circleFill)
                    }
                LogsViewer()
                    .tabItem {
                        Label("Debug", systemSymbol: .circleFill)
                    }
            }
            .tabViewStyle(.automatic)
            .environmentObject(settings)
            .task {
                let center = UNUserNotificationCenter.current()
                _ = try? await center.requestAuthorization(
                    options: [.alert, .sound, .badge]
                )
                // Configure Kingfisher to use our app delegate for auth challenges
                ImageDownloader.default.authenticationChallengeResponder = appDelegate
            }
        }
        WKNotificationScene(controller: NotificationController.self, category: "openHABNotification")
    }

    init() {
        DispatchQueue.main.async {
            AppMessageService.singleton.requestApplicationContext()
        }
    }
}
