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
import os.log

/// An event emitted by `SitemapPageLoader.stream(...)`.
public enum SitemapPageEvent: Sendable {
    /// The initial (non-long-poll) fetch completed.
    /// `page` is `nil` if the server returned no data.
    case initialFetch(OpenHABPage?)
    /// A successful long-poll response. `requestMs` is the HTTP request duration in milliseconds.
    case longPoll(OpenHABPage, requestMs: Int)
}

/// Streams `SitemapPageEvent` updates for a sitemap page.
///
/// The first value yielded is `initialFetch` from a short (non-long-poll) request,
/// always emitted even if the server returned no page. Subsequent values are `longPoll`
/// events from the long-polling loop carrying real request timing. Transient errors inside
/// the loop are retried with exponential back-off (1–30 s) and jitter. The stream finishes:
/// - cleanly on task cancellation,
/// - with an error if the initial request throws or a non-retryable error escapes
///   the long-poll loop.
public enum SitemapPageLoader {
    /// Streams page events using a pre-existing service.
    ///
    /// - Parameters:
    ///   - sitemapName: Sitemap identifier.
    ///   - pageId: Page within the sitemap; empty string selects the root page.
    ///   - service: `OpenAPIService` to poll. The caller retains ownership.
    ///   - shouldRetry: Called on each long-poll error to decide whether to
    ///     back off and retry (`true`) or propagate the error and end the stream
    ///     (`false`). Defaults to retrying every error.
    public static func stream(sitemapName: String,
                              pageId: String = "",
                              service: OpenAPIService,
                              shouldRetry: @escaping @Sendable (any Error) -> Bool = { _ in true },
                              onLongPollError: @escaping @Sendable (any Error, _ requestMs: Int, _ willRetry: Bool) -> Void = { _, _, _ in }) -> AsyncThrowingStream<SitemapPageEvent, any Error> {
        AsyncThrowingStream<SitemapPageEvent, any Error> { continuation in
            let task = Task {
                do {
                    // Initial (non-long-poll) fetch — fatal on error. Always yields an event
                    // so consumers can clear loading state regardless of whether a page returned.
                    let initialPage = try await service.pollDataForPage(
                        sitemapname: sitemapName,
                        pageId: pageId,
                        longPolling: false
                    )
                    continuation.yield(.initialFetch(initialPage))

                    try Task.checkCancellation()

                    // Long-polling loop — retry transient errors with back-off.
                    var backoffAttempt = 0
                    while !Task.isCancelled {
                        let requestStart = Date()
                        do {
                            if let page = try await service.pollDataForPage(
                                sitemapname: sitemapName,
                                pageId: pageId,
                                longPolling: true
                            ) {
                                let requestMs = Int((Date().timeIntervalSince(requestStart) * 1000).rounded())
                                backoffAttempt = 0
                                continuation.yield(.longPoll(page, requestMs: requestMs))
                            }
                        } catch is CancellationError {
                            throw CancellationError()
                        } catch {
                            let requestMs = Int((Date().timeIntervalSince(requestStart) * 1000).rounded())
                            let willRetry = shouldRetry(error)
                            onLongPollError(error, requestMs, willRetry)
                            guard willRetry else { throw error }
                            backoffAttempt += 1
                            let retrySecs = min((UInt64(1) << UInt64(min(backoffAttempt, 5))), 30)
                            let baseNs = retrySecs * 1_000_000_000
                            let jitter = UInt64.random(in: 0 ..< max(1, baseNs / 2))
                            Logger.sitemapPageLoader.warning(
                                "Long-poll error (attempt \(backoffAttempt)): \(error.localizedDescription, privacy: .public). Retrying in \(Double(baseNs + jitter) / 1_000_000_000, format: .fixed(precision: 1), privacy: .public)s."
                            )
                            try await Task.sleep(nanoseconds: baseNs + jitter)
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
