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

@Suite("relativeWebViewPath(proxyURL:rootURLString:)")
struct RelativeWebViewPathFunctionTests {
    @Test func prefersProxyURLWhenPresent() {
        let proxy = URL(string: "https://host/proxy")!
        let result = relativeWebViewPath("/proxy/ui", proxyURL: proxy, rootURLString: "https://host")
        #expect(result == "/ui")
    }

    @Test func proxyDoesNotMatchSiblingPath() {
        let proxy = URL(string: "https://host/proxy")!
        let result = relativeWebViewPath("/proxy2/ui", proxyURL: proxy, rootURLString: "https://host")
        #expect(result == "/proxy2/ui")
    }

    @Test func fallsBackToRootURLWhenNoProxy() {
        let result = relativeWebViewPath("/openhab/ui", proxyURL: nil, rootURLString: "https://host/openhab")
        #expect(result == "/ui")
    }

    @Test func rootURLDoesNotMatchSiblingPath() {
        let result = relativeWebViewPath("/openhab2/ui", proxyURL: nil, rootURLString: "https://host/openhab")
        #expect(result == "/openhab2/ui")
    }
}

@Suite("URL.relativeWebViewPath")
struct URLWebViewPathTests {
    // MARK: - Exact match

    @Test func exactBasePath() {
        let url = URL(string: "https://host/openhab")!
        #expect(url.relativeWebViewPath(for: "/openhab") == "/")
    }

    // MARK: - Normal sub-path stripping

    @Test func stripsBasePath() {
        let url = URL(string: "https://host/openhab")!
        #expect(url.relativeWebViewPath(for: "/openhab/ui") == "/ui")
    }

    @Test func stripsBasePathWithTrailingSlash() {
        let url = URL(string: "https://host/openhab")!
        #expect(url.relativeWebViewPath(for: "/openhab/ui/") == "/ui/")
    }

    // MARK: - Sibling-path false-match guard (the bug this fixes)

    @Test func doesNotMatchSiblingWithSamePrefix() {
        let url = URL(string: "https://host/openhab")!
        // /openhab2/ui must NOT be treated as a sub-path of /openhab
        #expect(url.relativeWebViewPath(for: "/openhab2/ui") == "/openhab2/ui")
    }

    @Test func doesNotMatchSiblingExactPrefix() {
        let url = URL(string: "https://host/openhab")!
        #expect(url.relativeWebViewPath(for: "/openhab2") == "/openhab2")
    }

    // MARK: - Edge cases

    @Test func emptyBasePath() {
        let url = URL(string: "https://host")!
        #expect(url.relativeWebViewPath(for: "/ui") == "/ui")
    }

    @Test func rootBasePath() {
        let url = URL(string: "https://host/")!
        #expect(url.relativeWebViewPath(for: "/ui") == "/ui")
    }

    @Test func unrelatedPath() {
        let url = URL(string: "https://host/openhab")!
        #expect(url.relativeWebViewPath(for: "/other/path") == "/other/path")
    }
}
