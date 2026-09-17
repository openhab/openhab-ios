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

import OpenHABCore
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "org.openhab.app", category: "SitemapPageViewModel")

@MainActor
extension SitemapPageViewModel {
    func handlePageHandlingError(_ error: any Error) {
        if error is CancellationError {
            logger.info("🔁 pageHandlingTask was cancelled")
            isLoading = false
            isUpdating = false
            return
        }

        if let decodingError = error as? DecodingError {
            guard !Task.isCancelled else {
                logger.info("Task cancelled, ignoring DecodingError")
                isLoading = false
                isUpdating = false
                return
            }
            logger.error("Decoding error: \(decodingError.localizedDescription)")
            self.error = SitemapPageError.serviceUnavailable
            isLoading = false
            isUpdating = false
            return
        }

        if let urlError = OpenAPIErrorInspector.underlyingURLError(from: error) {
            if urlError.code == .cancelled {
                logger.info("Task cancelled (URLError: cancelled)")
            } else if urlError.code == .timedOut {
                logger.info("Task timed out (URLError: timedOut)")
            } else if !Task.isCancelled {
                logger.error("ClientError: \(urlError.localizedDescription)")
                self.error = SitemapPageError.serviceUnavailable
            } else {
                logger.info("Task cancelled, ignoring ClientError")
            }
            isLoading = false
            isUpdating = false
            return
        }

        if let clientErrorDescription = OpenAPIErrorInspector.clientErrorDescription(from: error) {
            guard !Task.isCancelled else {
                logger.info("Task cancelled, ignoring ClientError")
                isLoading = false
                isUpdating = false
                return
            }
            logger.error("ClientError: \(clientErrorDescription)")
            self.error = SitemapPageError.serviceUnavailable
            isLoading = false
            isUpdating = false
            return
        }

        if let openAPIError = error as? OpenAPIServiceError {
            guard !Task.isCancelled else {
                logger.info("Task cancelled, ignoring OpenAPIServiceError: \(openAPIError.localizedDescription, privacy: .public)")
                isLoading = false
                isUpdating = false
                return
            }
            logger.error("OpenAPIServiceError: \(openAPIError.localizedDescription)")
            isLoading = false
            isUpdating = false
            return
        }

        guard !Task.isCancelled else {
            logger.info("Task cancelled, ignoring error")
            isLoading = false
            isUpdating = false
            return
        }
        logger.error("❌ Unhandled pageHandlingTask error: \(error.localizedDescription)")
        self.error = SitemapPageError.serviceUnavailable
        isLoading = false
        isUpdating = false
    }
}
