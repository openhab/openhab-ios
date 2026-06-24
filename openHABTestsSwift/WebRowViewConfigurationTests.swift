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

@testable import openHAB
import Testing
import WebKit

@Suite("webViewResolvedURL")
struct WebRowViewURLResolutionTests {
    @Test func relativePathResolvedAgainstLocalRootURL() {
        let url = webViewResolvedURL(urlString: "/static/foo.html", rootUrlString: "https://openhab.local:8443")
        #expect(url?.absoluteString == "https://openhab.local:8443/static/foo.html")
    }

    @Test func relativePathWithQueryResolvedAgainstRootURL() {
        let url = webViewResolvedURL(urlString: "/static/foo.html?x=1", rootUrlString: "https://openhab.local:8443")
        #expect(url?.absoluteString == "https://openhab.local:8443/static/foo.html?x=1")
    }

    @Test func absoluteURLIgnoresRootURL() {
        let url = webViewResolvedURL(urlString: "https://example.com/widget.html", rootUrlString: "https://openhab.local:8443")
        #expect(url?.absoluteString == "https://example.com/widget.html")
    }

    @Test func relativePathResolvedAgainstCloudRootURL() {
        let url = webViewResolvedURL(urlString: "/static/foo.html", rootUrlString: "https://home.myopenhab.org")
        #expect(url?.absoluteString == "https://home.myopenhab.org/static/foo.html")
    }

    @Test func rootURLChangeFromLocalToCloud() {
        let local = webViewResolvedURL(urlString: "/static/foo.html", rootUrlString: "https://openhab.local:8443")
        let cloud = webViewResolvedURL(urlString: "/static/foo.html", rootUrlString: "https://home.myopenhab.org")
        #expect(local?.absoluteString == "https://openhab.local:8443/static/foo.html")
        #expect(cloud?.absoluteString == "https://home.myopenhab.org/static/foo.html")
    }

    @Test func emptyURLStringReturnsNil() {
        let url = webViewResolvedURL(urlString: "", rootUrlString: "https://openhab.local:8443")
        #expect(url == nil)
    }

    @Test func relativePathWithEmptyRootReturnsNil() {
        let url = webViewResolvedURL(urlString: "/static/foo.html", rootUrlString: "")
        #expect(url == nil)
    }
}

@Suite("WebRowViewConfigurationFactory")

struct WebRowViewConfigurationTests {
    @MainActor
    @Test
    func webRowConfigurationAllowsInlineMutedAutoplay() {
        let configuration = WebRowViewConfigurationFactory.make(homeId: UUID())

        #expect(configuration.allowsInlineMediaPlayback)
        #expect(configuration.mediaTypesRequiringUserActionForPlayback == [])
    }

    @available(iOS 17, *)
    @MainActor
    @Test
    func webRowConfigurationUsesPerHomeDerivedDataStore() {
        let homeId = UUID()
        let configuration = WebRowViewConfigurationFactory.make(homeId: homeId)
        let expectedStoreID = WebRowViewConfigurationFactory.widgetStoreID(for: homeId)

        #expect(configuration.websiteDataStore.identifier == expectedStoreID)
    }

    @available(iOS 17, *)
    @MainActor
    @Test
    func widgetStoreIsIsolatedFromMainUIStore() {
        // Verify for a range of UUIDs including one whose version nibble is already "5"
        // to exercise the XOR path rather than a nibble-replacement assumption.
        let v4Home = UUID()
        let v5Home = UUID(uuidString: v4Home.uuidString.replacingCharacters(
            in: v4Home.uuidString.index(v4Home.uuidString.startIndex, offsetBy: 14) ... v4Home.uuidString.index(v4Home.uuidString.startIndex, offsetBy: 14),
            with: "5"
        ))!
        #expect(WebRowViewConfigurationFactory.widgetStoreID(for: v4Home) != v4Home)
        #expect(WebRowViewConfigurationFactory.widgetStoreID(for: v5Home) != v5Home)
    }

    @available(iOS 17, *)
    @MainActor
    @Test
    func separateHomesGetSeparateDataStores() {
        let idA = UUID()
        let idB = UUID()
        let configA = WebRowViewConfigurationFactory.make(homeId: idA)
        let configB = WebRowViewConfigurationFactory.make(homeId: idB)

        #expect(configA.websiteDataStore.identifier != configB.websiteDataStore.identifier)
    }
}
