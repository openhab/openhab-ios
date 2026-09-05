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
import Kingfisher
import Observation
import OpenHABCore
import os.log
import SwiftUI

/// Timer manager that persists across view updates
@MainActor
@Observable
private final class ImageRefreshTimer {
    var refreshCount = 0
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    private var currentInterval = 0
    private var isActive = false

    func configure(interval: Int) {
        // Only restart timer if interval changed or timer is not active
        guard interval != currentInterval || !isActive else { return }
        currentInterval = interval
        isActive = false

        timerTask?.cancel()
        timerTask = nil

        guard interval > 0 else { return }

        let intervalSeconds = max(0.1, Double(interval) / 1000.0)
        Logger.widgets.info("Starting image refresh timer with interval \(intervalSeconds) seconds")

        isActive = true
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(intervalSeconds))
                guard !Task.isCancelled else { return }
                Logger.widgets.info("Image refresh timer fired")
                self?.refreshCount += 1
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
        isActive = false
    }

    deinit {
        timerTask?.cancel()
    }
}

struct ImageRow: View, Equatable {
    let url: URL?
    let refresh: Int // Refresh interval in milliseconds, 0 means no refresh

    @State private var refreshTimer = ImageRefreshTimer()
    @ObservedObject private var networkTracker = MainActorNetworkTracker.shared

    /// For refreshing images, append a query parameter to bust the cache
    private var displayUrl: URL? {
        guard let url else { return nil }
        guard refresh > 0 else { return url }

        // Always add _r parameter when refresh is enabled to prevent stale cache
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "_r", value: "\(refreshTimer.refreshCount)"))
        components?.queryItems = queryItems
        return components?.url ?? url
    }

    var body: some View {
        KFImage.url(displayUrl)
            .withOpenHABCredentials(for: networkTracker.activeConnection)
            .cacheMemoryOnly(refresh > 0)
            .loadDiskFileSynchronously()
            .resizable()
            .aspectRatio(contentMode: .fit)
            .onAppear {
                refreshTimer.configure(interval: refresh)
            }
            .onDisappear {
                refreshTimer.stop()
            }
    }

    init(url: URL?, refresh: Int = 0) {
        self.url = url
        self.refresh = refresh
    }

    nonisolated static func == (lhs: ImageRow, rhs: ImageRow) -> Bool {
        lhs.url == rhs.url && lhs.refresh == rhs.refresh
    }
}

#Preview {
    let previewRootURL = "http://192.168.2.10:8080"
    let iconUrl = Endpoint.icon(
        rootUrl: previewRootURL,
        version: 2,
        icon: "Switch",
        state: "ON",
        iconType: .svg,
        iconColor: ""
    )?.url
    ImageRow(url: iconUrl, refresh: 0)
}
