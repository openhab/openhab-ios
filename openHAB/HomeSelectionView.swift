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

import FirebaseCrashlytics
import Kingfisher
import OpenHABCore
import os
import SafariServices
import SFSafeSymbols
import SwiftUI
import WebKit

struct HomeSelectionView: View {
    @State private var showingCacheAlert = false
    @State private var showCrashReportingAlert = false
    @State private var showUselastPathAlert = false

    @State private var hasBeenLoaded = false

    @State private var homes: [UUID] = []

    @Environment(\.dismiss) private var dismiss

    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

    private let logger = Logger(subsystem: "org.openhab.app", category: "SettingsView")

    var body: some View {
        Form {
            List(homes, id: \.self) {
                Text(Preferences.storedPreferences[$0.uuidString]?["homeName"] as? String ?? "")
                // TODO: selection of name in list changes settings
                // TODO: options like remove, rename (or should we rename in settings?)
            }
        }
        .onAppear {
            homes = Preferences.listStoredPreferences()
        }
        .formStyle(.grouped)
        .navigationBarTitle("homeSelection")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {
                    addHome()
                }, label: {
                    Image(systemSymbol: .plus)
                })
            }
        }
    }

    private func addHome() {
        // TODO: alert to insert name for home, store and dismiss
    }
}

#Preview {
    HomeSelectionView()
}
