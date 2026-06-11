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

import OpenAPIRuntime
@testable import OpenHABCore
import Testing

struct SitemapPageViewModelRetryPolicyTests {
    // MARK: URL errors

    @Test(arguments: [
        URLError.Code.timedOut,
        .networkConnectionLost,
        .cannotConnectToHost,
        .notConnectedToInternet,
        .cannotFindHost
    ])
    func transientURLErrorsRetry(_ code: URLError.Code) {
        #expect(SitemapPageViewModelBase.shouldRetryPolling(after: URLError(code)))
    }

    @Test(arguments: [URLError.Code.badURL, .userAuthenticationRequired, .fileDoesNotExist])
    func nonTransientURLErrorsDoNotRetry(_ code: URLError.Code) {
        #expect(!SitemapPageViewModelBase.shouldRetryPolling(after: URLError(code)))
    }

    // MARK: OpenAPI service errors — undocumented status codes

    @Test(arguments: [408, 429, 499, 500, 502, 503, 504])
    func transientHTTPStatusCodesRetry(_ statusCode: Int) {
        let error = OpenAPIServiceError.undocumented(statusCode: statusCode, undocumentedPayload: .init())
        #expect(SitemapPageViewModelBase.shouldRetryPolling(after: error))
    }

    @Test(arguments: [200, 201, 400, 401, 403, 404])
    func terminalHTTPStatusCodesDoNotRetry(_ statusCode: Int) {
        let error = OpenAPIServiceError.undocumented(statusCode: statusCode, undocumentedPayload: .init())
        #expect(!SitemapPageViewModelBase.shouldRetryPolling(after: error))
    }

    @Test
    func namedOpenAPIErrorCasesDoNotRetry() {
        #expect(!SitemapPageViewModelBase.shouldRetryPolling(after: OpenAPIServiceError.badRequest))
        #expect(!SitemapPageViewModelBase.shouldRetryPolling(after: OpenAPIServiceError.notFound))
        #expect(!SitemapPageViewModelBase.shouldRetryPolling(after: OpenAPIServiceError.noRootURL))
        #expect(!SitemapPageViewModelBase.shouldRetryPolling(after: OpenAPIServiceError.unAuthorized))
    }

    @Test
    func unknownErrorDoesNotRetry() {
        struct ArbitraryError: Error {}
        #expect(!SitemapPageViewModelBase.shouldRetryPolling(after: ArbitraryError()))
    }
}
