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
}

@MainActor
private func makeWebContainerContent(_ config: WebRowConfig) -> WebContainerContent {
    WebContainerContent(input: config.input)
}

private struct WebContainerContent: View {
    let input: MediaRowInput
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        let displayState = input.displayState
        VStack(alignment: .leading, spacing: 8) {
            if !displayState.labelText.isEmpty, input.labelSourceRawValue == OpenHABWidget.LabelSource.sitemapDefinition.rawValue {
                let labelText = displayState.labelText
                Text(labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))
            }

            WebRowView(urlString: input.url, rootUrlString: viewModel.openHABRootUrl ?? "")
                .frame(height: input.preferredRowHeight.map { CGFloat($0) })
                .clipShape(.rect(cornerRadius: 8))

            if let labelValue = displayState.labelValue, !labelValue.isEmpty {
                Text(labelValue)
                    .ohTextToken(.rowValueCompact)
                    .foregroundStyle(input.valueColor.isEmpty ? .secondary : Color(fromString: input.valueColor))
            }
        }
    }
}

@MainActor
enum WebRowViewConfigurationFactory {
    static func make() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        return configuration
    }
}

struct WidgetWebViewContainerView: View {
    let input: MediaRowInput

    var body: some View {
        makeWebContainerContent(
            WebRowConfig(
                input: input
            )
        )
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
            if challenge.protectionSpace.authenticationMethod.isAny(of: NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodDefault) {
                return await onReceiveSessionTaskChallenge(with: challenge)
            }
            return await onReceiveSessionChallenge(with: challenge)
        }
    }

    let urlString: String
    let rootUrlString: String

    private var webURL: URL? {
        guard !urlString.isEmpty else { return nil }
        if let url = URL(string: urlString), url.scheme != nil, url.host != nil {
            return url
        }
        guard !rootUrlString.isEmpty, let base = URL(string: rootUrlString) else { return nil }
        return URL(string: urlString, relativeTo: base)?.absoluteURL
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WebRowViewConfigurationFactory.make())
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
