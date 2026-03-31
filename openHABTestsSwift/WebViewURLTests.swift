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

import Foundation
@testable import openHAB
import Testing

@Suite("WebViewURLHelper")
struct WebViewURLTests {
    // MARK: - appendPath

    @Test("Appends simple path to base URL")
    func appendSimplePath() {
        let base = URL(string: "https://openhab.local:8443")!
        let result = WebViewURLHelper.appendPath("/dashboard", to: base)
        #expect(result?.absoluteString == "https://openhab.local:8443/dashboard")
    }

    @Test("Appends path with query to base URL")
    func appendPathWithQuery() {
        let base = URL(string: "https://openhab.local:8443")!
        let result = WebViewURLHelper.appendPath("/page?param=value", to: base)
        #expect(result?.absoluteString == "https://openhab.local:8443/page?param=value")
    }

    @Test("Appends path to URL that already has a path")
    func appendToExistingPath() {
        let base = URL(string: "https://openhab.local:8443/api")!
        let result = WebViewURLHelper.appendPath("/v1/items", to: base)
        #expect(result?.absoluteString == "https://openhab.local:8443/api/v1/items")
    }

    // MARK: - normalizeForComparison

    @Test("Normalizes URL removing trailing slash")
    func normalizeRemovesTrailingSlash() {
        let result = WebViewURLHelper.normalizeForComparison("https://openhab.local:8443/", includeBasePath: true)
        #expect(result == "https://openhab.local:8443")
    }

    @Test("Normalizes URL removing fragment")
    func normalizeRemovesFragment() {
        let result = WebViewURLHelper.normalizeForComparison("https://openhab.local:8443/page#section", includeBasePath: true)
        #expect(result == "https://openhab.local:8443/page")
    }

    @Test("Base-only normalization strips path and query")
    func normalizeBaseOnly() {
        let result = WebViewURLHelper.normalizeForComparison("https://openhab.local:8443/some/path?q=1#frag", includeBasePath: false)
        #expect(result == "https://openhab.local:8443")
    }

    @Test("Returns nil for nil input")
    func normalizeNilInput() {
        #expect(WebViewURLHelper.normalizeForComparison(nil) == nil)
    }

    @Test("Returns nil for empty string")
    func normalizeEmptyString() {
        #expect(WebViewURLHelper.normalizeForComparison("") == nil)
    }

    @Test("Same base URL comparison works")
    func sameBaseURLComparison() {
        let url1 = WebViewURLHelper.normalizeForComparison("https://openhab.local:8443/page1", includeBasePath: false)
        let url2 = WebViewURLHelper.normalizeForComparison("https://openhab.local:8443/page2", includeBasePath: false)
        #expect(url1 == url2)
    }

    @Test("Different base URL comparison works")
    func differentBaseURLComparison() {
        let url1 = WebViewURLHelper.normalizeForComparison("https://openhab.local:8443/page", includeBasePath: false)
        let url2 = WebViewURLHelper.normalizeForComparison("https://other.server:9090/page", includeBasePath: false)
        #expect(url1 != url2)
    }

    // MARK: - resolveWebViewURL

    @Test("Uses base URL when no proxy and no path")
    func resolveBaseOnly() {
        let base = URL(string: "https://openhab.local:8443")!
        let result = WebViewURLHelper.resolveWebViewURL(baseURL: base, proxyURL: nil, path: nil, defaultPath: "")
        #expect(result?.absoluteString == "https://openhab.local:8443")
    }

    @Test("Uses proxy URL when provided")
    func resolveWithProxy() {
        let base = URL(string: "https://openhab.local:8443")!
        let proxy = URL(string: "https://myopenhab.org/proxy")!
        let result = WebViewURLHelper.resolveWebViewURL(baseURL: base, proxyURL: proxy, path: nil, defaultPath: "")
        #expect(result?.absoluteString == "https://myopenhab.org/proxy")
    }

    @Test("Appends explicit path")
    func resolveWithExplicitPath() {
        let base = URL(string: "https://openhab.local:8443")!
        let result = WebViewURLHelper.resolveWebViewURL(baseURL: base, proxyURL: nil, path: "/dashboard", defaultPath: "/default")
        #expect(result?.absoluteString == "https://openhab.local:8443/dashboard")
    }

    @Test("Uses default path when no explicit path")
    func resolveWithDefaultPath() {
        let base = URL(string: "https://openhab.local:8443")!
        let result = WebViewURLHelper.resolveWebViewURL(baseURL: base, proxyURL: nil, path: nil, defaultPath: "/default")
        #expect(result?.absoluteString == "https://openhab.local:8443/default")
    }

    @Test("Proxy URL with explicit path")
    func resolveProxyWithPath() {
        let base = URL(string: "https://openhab.local:8443")!
        let proxy = URL(string: "https://myopenhab.org/proxy")!
        let result = WebViewURLHelper.resolveWebViewURL(baseURL: base, proxyURL: proxy, path: "/page", defaultPath: "")
        #expect(result?.absoluteString == "https://myopenhab.org/proxy/page")
    }
}
