// Copyright (c) 2010-2020 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import OpenHABCoreWatch
import os.log
import SwiftUI
import WatchConnectivity

// swiftlint:disable file_types_order
struct PreferencesSwiftUIView: View {
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

    var applicationVersionNumber: String = {
        let versionNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String

        return "V\(versionNumber).\(buildNumber)"
    }()

    var body: some View {
        List {
            PreferencesRowUIView(label: "Version", content: applicationVersionNumber).font(.footnote)
            PreferencesRowUIView(label: "Active URL", content: settings.openHABRootUrl).font(.footnote)
            PreferencesRowUIView(label: "Local URL", content: settings.localUrl).font(.footnote)
            PreferencesRowUIView(label: "Remote URL", content: settings.remoteUrl).font(.footnote)
            PreferencesRowUIView(label: "Sitemap", content: settings.sitemapName).font(.footnote)
            PreferencesRowUIView(label: "Username", content: settings.openHABUsername).font(.footnote)
            HStack {
                Button(action: { AppMessageService.singleton.requestApplicationContext()
                }, label: { Text("Sync preferences") })
            }
        }
    }
}

struct PreferencesSwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesSwiftUIView()
    }
}
