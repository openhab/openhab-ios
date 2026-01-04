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
import os

actor PageLoader {
    private var openAPIService: OpenAPIService
    private var pageId: String
    private var defaultSitemap: String

    private var lastFetchedPage: OpenHABPage? // Store latest page data

    init(service: OpenAPIService, pageId: String, defaultSitemap: String) {
        openAPIService = service
        self.pageId = pageId
        self.defaultSitemap = defaultSitemap
    }

    func updatePageConfig(newPageId: String, newSitemap: String) {
        pageId = newPageId
        defaultSitemap = newSitemap
        // swiftformat:disable:next redundantSelf
        Logger.pageLoader.info("🔄 Updated config: pageId = \(self.pageId), defaultSitemap = \(self.defaultSitemap)")
    }

    func updateAPIService(newService: OpenAPIService) {
        openAPIService = newService
        Logger.pageLoader.info("🔄 Updated OpenAPIService instance")
    }

    func fetchPage(longPolling: Bool) async throws -> OpenHABPage? {
        Logger.pageLoader.info("📡 Fetching page... (longPolling: \(longPolling))")
        let page = try await openAPIService.pollDataForPage(
            sitemapname: defaultSitemap,
            pageId: pageId,
            longPolling: longPolling
        )
        try Task.checkCancellation()

        return page
    }
}
