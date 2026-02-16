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

import CommonUI
import OpenHABCore
import os.log
import SwiftUI
import WebKit

struct WidgetWebViewContainer: View {
    @ObservedObject var widget: OpenHABWidget

    var body: some View {
        let displayState = widget.displayState
        VStack(alignment: .leading, spacing: 8) {
            if !displayState.labelText.isEmpty, widget.labelSource == .sitemapDefinition {
                let labelText = displayState.labelText
                Text(labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
            }

            WebRowView(widget: widget)
                .frame(height: widget.preferredRowHeight)
                .clipShape(.rect(cornerRadius: 8))

            if let labelValue = displayState.labelValue, !labelValue.isEmpty {
                Text(labelValue)
                    .ohTextToken(.rowValueCompact)
                    .foregroundStyle(widget.valuecolor.isEmpty ? .secondary : Color(fromString: widget.valuecolor))
            }
        }
    }
}

struct WebRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var viewModel: SitemapPageViewModel
    @State private var page = WebPage()
    
    private var webURL: URL? {
        guard !widget.url.isEmpty else { return nil }
        return URL(string: widget.url)
    }

    var body: some View {
        WebView(page)
            .webViewBackForwardNavigationGestures(.disabled)
            .webViewMagnificationGestures(.enabled)
            .webViewTextSelection(.enabled)
            .onAppear {
                if let webURL {
                    let request = URLRequest(url: webURL)
                    let _ = page.load(request)
                }
            }
            .onChange(of: widget.url) { _, newURL in
                if let url = URL(string: newURL) {
                    let request = URLRequest(url: url)
                    let _ = page.load(request)
                }
            }
    }
}
