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

import CommonUI
import Kingfisher
import OpenHABCore
internal import SFSafeSymbols
import SwiftUI
import UserNotifications

@main
struct OpenHABWatch: App {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var settings = AppSettings.shared
    @State private var wasInBackground = false
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
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    wasInBackground = true
                case .active:
                    guard wasInBackground else { return }
                    wasInBackground = false
                    Task { @MainActor in
                        await userData.refreshUrl(force: true)
                    }
                default:
                    break
                }
            }
        }
        WKNotificationScene(controller: NotificationController.self, category: "openHABNotification")
    }
}
