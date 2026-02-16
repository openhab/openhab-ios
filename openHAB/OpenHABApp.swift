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

import OpenHABCore
import SwiftUI

@main
struct OpenHABApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var isMigrationComplete = false

    var body: some Scene {
        WindowGroup {
            if isMigrationComplete {
                OpenHABTabRootView()
            } else {
                SplashView()
                    .task {
                        await Preferences.migratePreferences()
                        isMigrationComplete = true
                        // Defer non-essential initialization to after first frame renders
                        try? await Task.sleep(for: .milliseconds(100))
                        appDelegate.performDeferredSetup()
                    }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .inactive:
                NotificationCenter.default.post(name: .disableScreenSaver, object: nil)
            case .active:
                appDelegate.startScreenSaverMonitoring()
            default:
                break
            }
        }
    }
}
