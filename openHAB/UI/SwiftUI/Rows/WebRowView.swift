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

/// Resolves a widget URL string against the active openHAB root URL.
/// Absolute URLs (scheme + host present) are returned unchanged.
/// Server-relative paths (e.g. "/static/foo.html") are resolved against rootUrlString.
/// Returns nil when the string is empty or a relative path cannot be resolved.
func webViewResolvedURL(urlString: String, rootUrlString: String) -> URL? {
    guard !urlString.isEmpty else { return nil }
    if let url = URL(string: urlString), url.scheme != nil, url.host != nil {
        return url
    }
    guard !rootUrlString.isEmpty, let base = URL(string: rootUrlString) else { return nil }
    return URL(string: urlString, relativeTo: base)?.absoluteURL
}

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
    static func make(homeId: UUID) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        // iOS 17+: use a per-home sandboxed store derived from homeId but distinct from
        // the store used by OpenHABWebViewController (which uses homeId directly).
        // Separate identifiers give independent cookie and HTTP-cache storage for widget
        // pages, preventing a widget from serving stale or mismatched assets to MainUI.
        // WebContent process assignment remains at WebKit's discretion.
        // Basic Auth challenge handling covers widget authentication.
        configuration.websiteDataStore = WKWebsiteDataStore(forIdentifier: widgetStoreID(for: homeId))
        return configuration
    }

    /// Derives a store ID that is per-home but distinct from every possible `homeId`.
    /// XOR with a fixed non-zero mask is bijective (different inputs → different outputs)
    /// and guarantees `widgetStoreID(x) ≠ x` for all x, regardless of UUID version.
    static func widgetStoreID(for homeId: UUID) -> UUID {
        // Mask bytes spell "WebRowViewStore!" in ASCII.
        let mask: uuid_t = (
            0x57, 0x65, 0x62, 0x52, 0x6F, 0x77, 0x56, 0x69,
            0x65, 0x77, 0x53, 0x74, 0x6F, 0x72, 0x65, 0x21
        )
        var bytes = homeId.uuid
        withUnsafeMutableBytes(of: &bytes) { dst in
            withUnsafeBytes(of: mask) { src in
                for i in dst.indices {
                    dst[i] ^= src[i]
                }
            }
        }
        return UUID(uuid: bytes)
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
        var lastLoadedURL: URL?
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
        webViewResolvedURL(urlString: urlString, rootUrlString: rootUrlString)
    }

    func makeUIView(context: Context) -> WKWebView {
        let homeId = Preferences.shared.currentHomePreferences.id
        let webView = WKWebView(frame: .zero, configuration: WebRowViewConfigurationFactory.make(homeId: homeId))
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let webURL, webURL != context.coordinator.lastLoadedURL else { return }
        context.coordinator.lastLoadedURL = webURL
        webView.load(URLRequest(url: webURL))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}
