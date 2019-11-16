// Copyright (c) 2010-2019 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import SwiftUI

// swiftlint:disable file_types_order
struct PreferencesSwiftUIView: View {
    var applicationVersionNumber: String = {
        let versionNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String

        return "V\(versionNumber).\(buildNumber)"
    }()

    var body: some View {
        List {
            PreferencesRowUIView(label: "Version", content: applicationVersionNumber)
            PreferencesRowUIView(label: "Local URL", content: Preferences.localUrl)
            PreferencesRowUIView(label: "Remote URL", content: Preferences.remoteUrl)
            PreferencesRowUIView(label: "Sitemap", content: Preferences.sitemapName)
            PreferencesRowUIView(label: "Username", content: Preferences.username)
        }.font(.footnote)
    }
}

struct PreferencesSwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesSwiftUIView()
    }
}
