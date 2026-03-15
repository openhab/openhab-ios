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

import SafariServices
import SwiftUI

struct AboutSettingsView: View {
    var appVersion: String {
        let appBuildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "\(appVersionString ?? "") (\(appBuildString ?? ""))"
    }

    var body: some View {
        Section(header: Text(LocalizedStringKey("about_settings"))) {
            LabeledContent("App Version", value: appVersion)

            NavigationLink {
                RTFTextView(rtfFileName: "legal")
                    .navigationTitle("Legal")
                    .navigationBarTitleDisplayMode(.inline)
            } label: {
                Text("Legal")
            }

            Button {
                presentPrivacyPolicy()
            } label: {
                Text("privacy_policy")
            }
        }
    }

    func presentPrivacyPolicy() {
        let vc = SFSafariViewController(url: .privacyPolicy)
        UIApplication.shared.firstKeyWindow?.rootViewController?.present(vc, animated: true)
    }
}

#Preview {
    NavigationStack {
        Form {
            AboutSettingsView()
        }
    }
}
