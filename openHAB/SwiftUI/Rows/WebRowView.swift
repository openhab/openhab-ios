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

private struct WebRowConfig {
    let input: MediaRowInput
    let widget: OpenHABWidget
}

@MainActor
private func makeWebContainerContent(_ config: WebRowConfig) -> WebContainerContent {
    WebContainerContent(input: config.input, widget: config.widget)
}

private struct WebContainerContent: View {
    let input: MediaRowInput
    @ObservedObject var widget: OpenHABWidget

    var body: some View {
        let displayState = input.displayState
        VStack(alignment: .leading, spacing: 8) {
            if !displayState.labelText.isEmpty, input.labelSourceRawValue == OpenHABWidget.LabelSource.sitemapDefinition.rawValue {
                let labelText = displayState.labelText
                Text(labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))
            }

            WebRowView(widget: widget)
                .frame(height: widget.preferredRowHeight)
                .clipShape(.rect(cornerRadius: 8))

            if let labelValue = displayState.labelValue, !labelValue.isEmpty {
                Text(labelValue)
                    .ohTextToken(.rowValueCompact)
                    .foregroundStyle(input.valueColor.isEmpty ? .secondary : Color(fromString: input.valueColor))
            }
        }
    }
}

struct WidgetWebViewContainer: View {
    @ObservedObject var widget: OpenHABWidget

    var body: some View {
        makeWebContainerContent(
            WebRowConfig(
                input: MediaRowInput.from(widget: widget),
                widget: widget
            )
        )
    }
}

struct WidgetWebViewContainerInputView: View {
    let rowID: RowID
    let input: MediaRowInput
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        if let widget = viewModel.widget(for: rowID) {
            makeWebContainerContent(
                WebRowConfig(
                    input: input,
                    widget: widget
                )
            )
        } else {
            EmptyView()
        }
    }
}

struct WebRowView: UIViewRepresentable {
    class Coordinator: NSObject, WKNavigationDelegate {
        private let logger = Logger(subsystem: "org.openhab", category: "WebRowViewCoordinator")

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
            logger.debug("WebView failed to load: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView,
                     respondTo challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            await onReceiveSessionChallenge(with: challenge)
        }
    }

    @ObservedObject var widget: OpenHABWidget

    private var webURL: URL? {
        guard !widget.url.isEmpty else { return nil }
        return URL(string: widget.url)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if let webURL {
            let request = URLRequest(url: webURL)
            webView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}
