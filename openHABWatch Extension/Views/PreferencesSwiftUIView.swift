// Copyright (c) 2010-2021 Contributors to the openHAB project
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

struct PreferencesSwiftUIView: View {
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

    var applicationVersionNumber: String = {
        let versionNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String

        return "V\(versionNumber).\(buildNumber)"
    }()

    var body: some View {
        List {
            PreferencesRowUIView(label: NSLocalizedString("version", comment: ""), content: applicationVersionNumber).font(.footnote)
            PreferencesRowUIView(label: NSLocalizedString("active_url", comment: ""), content: settings.openHABRootUrl).font(.footnote)
            PreferencesRowUIView(label: NSLocalizedString("local_url", comment: ""), content: settings.localUrl).font(.footnote)
            PreferencesRowUIView(label: NSLocalizedString("remote_url", comment: ""), content: settings.remoteUrl).font(.footnote)
            PreferencesRowUIView(label: NSLocalizedString("sitemap", comment: ""), content: settings.sitemapName).font(.footnote)
            PreferencesRowUIView(label: NSLocalizedString("username", comment: ""), content: settings.openHABUsername).font(.footnote)
            HStack {
                Button(action: { AppMessageService.singleton.requestApplicationContext() }, label: { Text(NSLocalizedString("sync_prefs", comment: "")) })
            }
        }
    }
}

struct PreferencesSwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesSwiftUIView()
    }
}
