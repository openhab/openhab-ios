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
import os.log
import SwiftUI
import WatchConnectivity

struct PreferencesSwiftUIView: View {
    @EnvironmentObject var settings: ObservableOpenHABDataObject

    var applicationVersionNumber: String = {
        let appBuildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "\(appVersionString ?? "") (\(appBuildString ?? ""))"
    }()

    var body: some View {
        List {
            LabeledContent(LocalizedStringKey("active_url"), value: settings.openHABRootUrl)
            LabeledContent(LocalizedStringKey("local_url"), value: settings.localUrl)
            LabeledContent(LocalizedStringKey("remote_url"), value: settings.remoteUrl)
            LabeledContent(LocalizedStringKey("sitemap"), value: settings.sitemapForWatch)
            LabeledContent(LocalizedStringKey("username"), value: settings.openHABUsername)
            LabeledContent(LocalizedStringKey("version"), value: applicationVersionNumber)
        }

        Button { AppMessageService.singleton.requestApplicationContext()
        } label: { Label("sync_prefs", systemSymbol: .arrowTriangle2Circlepath)
        }
        .buttonStyle(.borderedProminent)
    }
}

#Preview {
    PreferencesSwiftUIView()
        .environmentObject(ObservableOpenHABDataObject())
}
