// Copyright (c) 2010-2024 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import SDWebImage
import SDWebImageSVGCoder
import SwiftUI
import UserNotifications

@main
struct OpenHABWatch: App {
    @ObservedObject var settings = ObservableOpenHABDataObject.shared
    // https://developer.apple.com/documentation/watchkit/wkapplicationdelegate
    @WKApplicationDelegateAdaptor(OpenHABWatchAppDelegate.self) var appDelegate
    @ObservedObject var userData = UserData(sitemapName: ObservableOpenHABDataObject.shared.sitemapName)

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView(viewModel: userData)
                    .tabItem {
                        Label("Received", systemImage: "tray.and.arrow.down.fill")
                    }
                PreferencesSwiftUIView()
                    .tabItem {
                        Label("Preferences", systemImage: "person.crop.circle.fill")
                    }
            }
            .environmentObject(settings)
            .task {
                let center = UNUserNotificationCenter.current()
                _ = try? await center.requestAuthorization(
                    options: [.alert, .sound, .badge]
                )
            }
        }
        WKNotificationScene(controller: NotificationController.self, category: "openHABNotification")
    }

    init() {
        // Initialize SVGCoder
        let SVGCoder = SDImageSVGCoder.shared
        SDImageCodersManager.shared.addCoder(SVGCoder)
        SDWebImageDownloader.shared.config.operationClass = OpenHABImageDownloaderOperation.self
        let alwaysSendCreds = settings.openHABAlwaysSendCreds
        let openHABUsername = settings.openHABUsername
        let openHABPassword = settings.openHABPassword
        let requestModifier = SDWebImageDownloaderRequestModifier { (request) -> URLRequest? in
            guard alwaysSendCreds || request.url?.host?.hasSuffix("myopenhab.org") == true else {
                return request
            }
            guard !openHABUsername.isEmpty, !openHABPassword.isEmpty else {
                return request
            }
            var request = request
            request.headers.add(.authorization(username: openHABUsername, password: openHABPassword))
            return request
        }
        SDWebImageDownloader.shared.requestModifier = requestModifier
    }
}
