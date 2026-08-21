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
import os.log
import SwiftUI
import WatchConnectivity

struct HighlightDotRowModifier: ViewModifier {
    let showDot: Bool

    func body(content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
            .overlay(alignment: .topTrailing) {
                if showDot {
                    Circle()
                        .fill(Color.red.opacity(0.7))
                        .frame(width: 6, height: 6)
                        .offset(x: 0, y: 0)
                }
            }
    }
}

struct CompactLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .watchTextStyle(.detail)
            Spacer()
            configuration.content
                .watchTextStyle(.detail)
                .foregroundStyle(.secondary)
        }
//        .padding(.vertical, 4) // Reduces vertical space
    }
}

struct PreferencesSwiftUIView: View {
    @EnvironmentObject var settings: AppSettings

    /// The selected sitemap rendered per the synced display-mode and sort-order
    /// settings (e.g. just the name, just the label, or "Home – watch").
    private var selectedSitemapText: String {
        let sitemap = OpenHABSitemap(
            name: settings.sitemapForWatch,
            icon: "",
            label: settings.sitemapForWatchLabel,
            link: "",
            page: nil
        )
        return settings.sitemapNameLabelDisplayMode.combinedText(for: sitemap, sortedBy: settings.sortSitemapsBy)
    }

    var applicationVersionNumber: String = {
        let appBuildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "\(appVersionString ?? "") (\(appBuildString ?? ""))"
    }()

    var body: some View {
        List {
            LabeledContent(LocalizedStringKey("local_url"), value: settings.localConnectionConfig?.url ?? String(localized: "empty", comment: "local or remote URL: empty"))
                .highlightDotRow(if: settings.localConnectionConfig?.url == settings.openHABRootUrl)
            LabeledContent(LocalizedStringKey("remote_url"), value: settings.remoteConnectionConfig?.url ?? String(localized: "empty", comment: "local or remote URL: empty"))
                .highlightDotRow(if: settings.remoteConnectionConfig?.url == settings.openHABRootUrl)
            // Show the selected sitemap honoring the same display-mode / sort-order
            // setting as the phone (synced via WatchPreferences).
            LabeledContent(LocalizedStringKey("sitemap"), value: selectedSitemapText)
                .listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
            LabeledContent(LocalizedStringKey("version"), value: applicationVersionNumber)
                .listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 10)
        .labeledContentStyle(CompactLabeledContentStyle()) // 👈 Apply custom style
        .refreshable {
            AppMessageService.singleton.requestApplicationContext()
        }
    }
}

extension View {
    func highlightDotRow(if condition: Bool) -> some View {
        modifier(HighlightDotRowModifier(showDot: condition))
    }
}

#Preview {
    PreferencesSwiftUIView()
        .environmentObject(AppSettings())
}
