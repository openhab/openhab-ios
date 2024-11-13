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

import OpenHABCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: UserData
    @EnvironmentObject var settings: ObservableOpenHABDataObject
    @State var title = "openHAB"

    var body: some View {
        TabView {
            NavigationStack {
                SitemapView(viewModel: viewModel)
            }
            .tabItem {
                Label("Sitemap", systemSymbol: .circleFill)
            }
            NavigationStack {
                PreferencesSwiftUIView()
            }
            .tabItem {
                Label("Preferences", systemSymbol: .circleFill)
            }
            NavigationStack {
                LogsViewer(logService: LogService())
            }
            .tabItem {
                Label("Debug", systemSymbol: .circleFill)
            }
        }
        .tabViewStyle(.page)
    }
}

#Preview {
    ContentView(viewModel: .init())
        .environmentObject(ObservableOpenHABDataObject())
}
