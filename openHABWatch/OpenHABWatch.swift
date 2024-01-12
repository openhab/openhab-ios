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

class OpenHABRequestModifier: SDWebImageDownloaderRequestModifier {
    var appData: ObservableOpenHABDataObject

    public init(appData data: ObservableOpenHABDataObject) {
        appData = data
        super.init()
    }

    override func modifiedRequest(with request: URLRequest) -> URLRequest? {
        guard appData.openHABAlwaysSendCreds || request.url?.host?.hasSuffix("myopenhab.org") == true else {
            // The user did not choose for the credentials to be sent with every request.
            return request
        }

        let user = appData.openHABUsername
        let password = appData.openHABPassword
        guard !user.isEmpty, !password.isEmpty else {
            // In order to set the credentials on the `URLRequestt`, both username and password must be set up.
            return request
        }

        var request = request
        request.headers.add(.authorization(username: user, password: password))
        return request
    }
}

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
        SDImageCodersManager.shared.addCoder(SDImageSVGCoder.shared)
        SDWebImageDownloader.shared.config.operationClass = OpenHABImageDownloaderOperation.self
        SDWebImageDownloader.shared.requestModifier = OpenHABRequestModifier(appData: settings)
    }
}
