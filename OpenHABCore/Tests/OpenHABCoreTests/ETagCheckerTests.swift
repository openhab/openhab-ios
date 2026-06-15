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
@testable import OpenHABCore
import Testing

// MARK: - Mock URLProtocol

class MockURLProtocol: URLProtocol {
    // Use nonisolated(unsafe) to suppress concurrency warnings
    // Safe because tests run with .serialized, ensuring sequential execution
    nonisolated(unsafe) static var mockResponses: [URL: (statusCode: Int, headers: [String: String])] = [:]
    nonisolated(unsafe) static var shouldFail = false
    nonisolated(unsafe) static var error: Error?

    static func reset() {
        mockResponses.removeAll()
        shouldFail = false
        error = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        if MockURLProtocol.shouldFail {
            let error = MockURLProtocol.error ?? URLError(.badServerResponse)
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        guard let mock = MockURLProtocol.mockResponses[url] else {
            // Return 404 if no mock configured
            let response = HTTPURLResponse(
                url: url,
                statusCode: 404,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data())
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: mock.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: mock.headers
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("ETagChecker Tests", .serialized)
struct ETagCheckerTests {
    @Test("First run stores ETag and returns changed")
    func firstRunStoresETag() async throws {
        MockURLProtocol.reset()

        let testURL = try #require(URL(string: "https://example.com/index.html"))
        let etagValue = "\"abc123\""

        // Setup mock
        MockURLProtocol.mockResponses[testURL] = (200, ["etag": etagValue])

        // Create test instance
        let cache = makeInMemoryCache()
        let httpClient = makeMockHTTPClient()
        let checker = ETagChecker(httpClient: httpClient, cache: cache)

        // First check should return .changed
        let result = await checker.checkIfChanged(url: testURL)

        guard case .changed = result else {
            Issue.record("Expected .changed, got \(result)")
            return
        }

        // Verify ETag was stored (normalized without quotes)
        let storedETag = await cache.getETag(for: testURL.absoluteString)
        #expect(storedETag == "abc123")
    }

    @Test("Returns unchanged when ETag matches")
    func unchangedWhenETagMatches() async throws {
        MockURLProtocol.reset()

        let testURL = try #require(URL(string: "https://example.com/data.json"))
        let etagValue = "\"def456\""

        // Pre-populate cache
        let cache = makeInMemoryCache()
        await cache.storeETag(etagValue, for: testURL.absoluteString)

        // Mock returns same ETag
        MockURLProtocol.mockResponses[testURL] = (200, ["etag": etagValue])

        let httpClient = makeMockHTTPClient()
        let checker = ETagChecker(httpClient: httpClient, cache: cache)

        let result = await checker.checkIfChanged(url: testURL)

        guard case .unchanged = result else {
            Issue.record("Expected .unchanged, got \(result)")
            return
        }
    }

    @Test("Returns changed when ETag differs")
    func changedWhenETagDiffers() async throws {
        MockURLProtocol.reset()

        let testURL = try #require(URL(string: "https://example.com/api/v1/data"))
        let oldETag = "\"old123\""
        let newETag = "\"new456\""

        // Pre-populate cache with old ETag
        let cache = makeInMemoryCache()
        await cache.storeETag(oldETag, for: testURL.absoluteString)

        // Mock returns different ETag
        MockURLProtocol.mockResponses[testURL] = (200, ["etag": newETag])

        let httpClient = makeMockHTTPClient()
        let checker = ETagChecker(httpClient: httpClient, cache: cache)

        let result = await checker.checkIfChanged(url: testURL)

        guard case .changed = result else {
            Issue.record("Expected .changed, got \(result)")
            return
        }

        // Verify cache was updated with new ETag (normalized without quotes)
        let storedETag = await cache.getETag(for: testURL.absoluteString)
        #expect(storedETag == "new456")
    }

    @Test("Returns failed when network request fails")
    func failedOnNetworkError() async throws {
        MockURLProtocol.reset()

        let testURL = try #require(URL(string: "https://example.com/fail"))

        // Configure mock to fail
        MockURLProtocol.shouldFail = true
        MockURLProtocol.error = URLError(.networkConnectionLost)

        let cache = makeInMemoryCache()
        let httpClient = makeMockHTTPClient()
        let checker = ETagChecker(httpClient: httpClient, cache: cache)

        let result = await checker.checkIfChanged(url: testURL)

        guard case .failed = result else {
            Issue.record("Expected .failed, got \(result)")
            return
        }
    }

    @Test("Returns noETagSupport when no ETag header present")
    func noETagSupportWhenNoETagHeader() async throws {
        MockURLProtocol.reset()

        let testURL = try #require(URL(string: "https://example.com/no-etag"))

        // Mock response without ETag header
        MockURLProtocol.mockResponses[testURL] = (200, [:])

        let cache = makeInMemoryCache()
        let httpClient = makeMockHTTPClient()
        let checker = ETagChecker(httpClient: httpClient, cache: cache)

        let result = await checker.checkIfChanged(url: testURL)

        guard case .noETagSupport = result else {
            Issue.record("Expected .noETagSupport, got \(result)")
            return
        }
    }

    @Test("Normalizes quoted ETags")
    func normalizesQuotedETags() async throws {
        MockURLProtocol.reset()

        let testURL = try #require(URL(string: "https://example.com/normalize"))
        let quotedETag = "\"abc123\""
        let unquotedETag = "abc123"

        // Store quoted version
        let cache = makeInMemoryCache()
        await cache.storeETag(quotedETag, for: testURL.absoluteString)

        // Mock returns unquoted (after normalization they should match)
        MockURLProtocol.mockResponses[testURL] = (200, ["etag": unquotedETag])

        let httpClient = makeMockHTTPClient()
        let checker = ETagChecker(httpClient: httpClient, cache: cache)

        let result = await checker.checkIfChanged(url: testURL)

        // Should recognize as unchanged (normalized comparison)
        guard case .unchanged = result else {
            Issue.record("Expected .unchanged (normalized), got \(result)")
            return
        }
    }

    @Test("Handles case-insensitive ETag header")
    func caseInsensitiveETagHeader() async throws {
        MockURLProtocol.reset()

        let testURL = try #require(URL(string: "https://example.com/case-test"))
        let etagValue = "\"xyz789\""

        // Mock with lowercase "etag" (not "ETag")
        MockURLProtocol.mockResponses[testURL] = (200, ["etag": etagValue])

        let cache = makeInMemoryCache()
        let httpClient = makeMockHTTPClient()
        let checker = ETagChecker(httpClient: httpClient, cache: cache)

        let result = await checker.checkIfChanged(url: testURL)

        guard case .changed = result else {
            Issue.record("Expected .changed, got \(result)")
            return
        }

        // Verify it found and stored the ETag (normalized without quotes)
        let storedETag = await cache.getETag(for: testURL.absoluteString)
        #expect(storedETag == "xyz789")
    }

    @Test("Weak ETags are supported")
    func weakETagsSupported() async throws {
        MockURLProtocol.reset()

        let testURL = try #require(URL(string: "https://example.com/weak-etag"))
        let weakETag = "W/\"abc123\""

        // Store weak ETag
        let cache = makeInMemoryCache()
        await cache.storeETag(weakETag, for: testURL.absoluteString)

        // Mock returns same weak ETag
        MockURLProtocol.mockResponses[testURL] = (200, ["etag": weakETag])

        let httpClient = makeMockHTTPClient()
        let checker = ETagChecker(httpClient: httpClient, cache: cache)

        let result = await checker.checkIfChanged(url: testURL)

        guard case .unchanged = result else {
            Issue.record("Expected .unchanged (weak ETag match), got \(result)")
            return
        }
    }

    // MARK: - Helper Methods

    private func makeInMemoryCache() -> ETagCache {
        ETagCache(persistencePath: nil)
    }

    private func makeMockHTTPClient() -> HTTPClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        // Create ConnectionConfiguration with dummy values
        let connConfig = ConnectionConfiguration(
            url: "https://example.com",
            username: "",
            password: "",
            alwaysSendBasicAuth: false,
            ignoreSSL: false,
            priority: 0
        )

        return HTTPClient(
            baseURL: nil,
            connectionConfiguration: connConfig,
            sessionConfiguration: config
        )
    }
}
