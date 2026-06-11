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

import Combine
import Foundation

/// Shared base for sitemap page view models on all platforms.
///
/// Provides the common published state (`currentPage`, `isLoading`, `error`) and task-lifecycle
/// helpers (`runNewHandlingTask`, `stopHandling`) so that platform-specific subclasses can focus
/// on connection resolution, UI adaptation, and command handling.
@MainActor
open class SitemapPageViewModelBase: ObservableObject {
    @Published public var currentPage: OpenHABPage?
    @Published public var isLoading = true
    @Published public var error: (any LocalizedError)?

    /// Active page-handling task. Subclasses may read and write this directly.
    public var pageHandlingTask: Task<Void, Never>?
    /// Key identifying the currently running task (e.g. `"sitemapName|pageId"`).
    public var currentHandlingKey: String?

    private var taskGeneration = 0

    public init() {}

    /// Shared long-poll retry policy. Returns `true` for transient network and server errors,
    /// including HTTP 500 which can be a transient server-side hiccup.
    public nonisolated static func shouldRetryPolling(after error: any Error) -> Bool {
        if let urlError = OpenAPIErrorInspector.underlyingURLError(from: error) {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .cannotConnectToHost, .notConnectedToInternet, .cannotFindHost:
                return true
            default:
                break
            }
        }

        if let openAPIError = error as? OpenAPIServiceError {
            switch openAPIError {
            case let .undocumented(statusCode, _):
                return statusCode == 429 || statusCode == 500 || statusCode == 408 || statusCode == 499 || statusCode == 502 || statusCode == 503 || statusCode == 504
            case .badRequest, .notFound, .noRootURL, .unAuthorized:
                break
            }
        }

        return false
    }

    /// Starts a new page-handling task, cancelling any running one first.
    ///
    /// When a non-cancelled task for `key` is already running and `force` is `false`, this is a
    /// no-op and returns `false`. Otherwise cancels the existing task, starts `body`, and returns
    /// `true`. The task slot (`pageHandlingTask`, `currentHandlingKey`) is automatically cleared
    /// when `body` returns.
    @discardableResult
    public func runNewHandlingTask(key: String, force: Bool = false, _ body: @escaping @MainActor () async -> Void) -> Bool {
        if !force, let task = pageHandlingTask, !task.isCancelled, currentHandlingKey == key {
            return false
        }
        pageHandlingTask?.cancel()
        taskGeneration += 1
        let gen = taskGeneration
        currentHandlingKey = key
        pageHandlingTask = Task { @MainActor [weak self] in
            await body()
            guard let self, taskGeneration == gen else { return }
            pageHandlingTask = nil
            currentHandlingKey = nil
        }
        return true
    }

    /// Iterates the sitemap page stream for a resolved connection, calling `handlePageUpdate` for
    /// each page received. Clears `isLoading` on the first event. Uses the shared retry policy.
    /// Throws `CancellationError` on task cancellation; rethrows non-retryable stream errors.
    public func runStreamLoop(sitemapName: String, pageId: String, connectionInfo: ConnectionInfo) async throws {
        let service = try OpenAPIService(
            connectionConfiguration: connectionInfo.configuration,
            serviceConfiguration: .longTerm
        )
        for try await event in SitemapPageLoader.stream(
            sitemapName: sitemapName,
            pageId: pageId,
            service: service,
            shouldRetry: Self.shouldRetryPolling(after:)
        ) {
            try Task.checkCancellation()
            isLoading = false
            let page: OpenHABPage? = switch event {
            case let .initialFetch(page): page
            case let .longPoll(page, _): page
            }
            if let page {
                handlePageUpdate(page, event: event)
            }
        }
    }

    /// Called for each page received from the stream.
    ///
    /// The default implementation updates `currentPage` when the page title changes, avoiding
    /// unnecessary `objectWillChange` notifications that would reset scroll position. Override to
    /// add platform-specific behaviour (e.g. widget list updates on watchOS).
    open func handlePageUpdate(_ page: OpenHABPage, event: SitemapPageEvent) {
        if currentPage?.title != page.title {
            currentPage = page
        }
    }

    /// Cancels the active task and resets loading state.
    public func stopHandling() {
        pageHandlingTask?.cancel()
        pageHandlingTask = nil
        currentHandlingKey = nil
        isLoading = false
    }

    deinit {
        pageHandlingTask?.cancel()
    }
}
