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
import OpenHABCore
import os.log
import SwiftUI

private struct ImageRowConfig {
    let input: MediaRowInput
    let viewModel: SitemapPageViewModel
}

@MainActor
private func makeImageRowContent(_ config: ImageRowConfig) -> ImageRowContent {
    ImageRowContent(input: config.input, viewModel: config.viewModel)
}

private struct ImageRowContent: View {
    private struct ChartDisplayState {
        let key: String
        let url: URL?
    }

    private struct RegularImageState {
        let url: URL?
        let image: KFCrossPlatformImage
    }

    let input: MediaRowInput
    @ObservedObject var viewModel: SitemapPageViewModel
    @ObservedObject private var networkTracker = MainActorNetworkTracker.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var refreshTimer: Timer?
    @State private var forceRefreshKey = UUID()
    @State private var lastChartImage: KFCrossPlatformImage?
    @State private var lastRegularImageState: RegularImageState?
    @State private var chartDisplayState: ChartDisplayState?

    private let logger = Logger(subsystem: "org.openhab", category: "ImageRowView")

    private var shouldCache: Bool {
        input.refresh == 0
    }

    private var chartStyle: ChartStyle {
        colorScheme == .light ? .light : .dark
    }

    private var isChartByMediaKind: Bool {
        input.imageDescriptor.mediaKind == .chart
    }

    private var chartWidgetVersion: Int {
        viewModel.widgetUpdateVersion(for: input.widgetId)
    }

    private var chartSyncToken: String {
        let themeKey = switch chartStyle {
        case .dark: "dark"
        case .light: "light"
        }
        let rootKey = viewModel.openHABRootUrl ?? ""
        return "\(isChartByMediaKind)|\(input.widgetId)|\(input.imageDescriptor.period)|\(input.url)|\(rootKey)|\(themeKey)|\(chartWidgetVersion)"
    }

    var body: some View {
        let displayState = input.displayState
        VStack(alignment: .leading, spacing: 8) {
            if !displayState.labelText.isEmpty, input.labelSourceRawValue == OpenHABWidget.LabelSource.sitemapDefinition.rawValue {
                let labelText = displayState.labelText
                Text(labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))
            }
            if isChartByMediaKind {
                chartImageView
            } else {
                regularImageView
            }

            // Only show labelValue for image widgets, not charts
            if input.imageDescriptor.mediaKind == .image, let labelValue = displayState.labelValue, !labelValue.isEmpty {
                Text(labelValue)
                    .ohTextToken(.rowValueCompact)
                    .foregroundStyle(input.valueColor.isEmpty ? .secondary : Color(fromString: input.valueColor))
            }
        }
        .onAppear {
            setupRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
        .task(id: chartSyncToken) {
            syncChartDisplayURL()
        }
        .onChange(of: input.refresh) {
            setupRefreshTimer()
        }
    }

    @ViewBuilder
    private var chartImageView: some View {
        let currentChartKey = makeChartDisplayKey()
        let effectiveChartURL: URL? = if chartDisplayState?.key == currentChartKey {
            chartDisplayState?.url
        } else {
            nil
        }

        KFImage(effectiveChartURL)
            .withOpenHABCredentials(for: networkTracker.activeConnection)
            .cacheMemoryOnly(false)
            .cacheOriginalImage(true)
            .fade(duration: 0)
            .placeholder {
                if let lastChartImage {
                    Image(uiImage: lastChartImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Color.gray.opacity(0.1)
                        .frame(height: 200)
                        .clipShape(.rect(cornerRadius: 8))
                }
            }
            .onSuccess { result in
                guard chartDisplayState?.key == currentChartKey, chartDisplayState?.url == effectiveChartURL else {
                    return
                }
                lastChartImage = result.image
            }
            .resizable()
            .id(effectiveChartURL?.absoluteString ?? currentChartKey)
            .aspectRatio(contentMode: .fit)
            .frame(maxHeight: 300)
            .clipShape(.rect(cornerRadius: 8))
    }

    @ViewBuilder
    private var regularImageView: some View {
        switch input.imageDescriptor.resolveImagePayload(rootUrl: viewModel.openHABRootUrl ?? "", chartStyle: chartStyle) {
        case let .embedded(data: data):
            let cacheKey = if shouldCache {
                "\(input.widgetId)-\(data.hashValue)"
            } else {
                "\(input.widgetId)-\(forceRefreshKey)"
            }
            let provider = RawImageDataProvider(data: data, cacheKey: cacheKey)
            KFImage(source: .provider(provider))
                .withOpenHABCredentials(for: networkTracker.activeConnection)
                .setProcessor(OpenHABImageProcessor(svgMaxSize: nil))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
                .clipShape(.rect(cornerRadius: 8))
        case let .link(url):
            if url?.pathExtension.lowercased() == "gif" {
                KFAnimatedImage(url)
                    .withOpenHABCredentials(for: networkTracker.activeConnection)
                    .configure { $0.contentMode = .scaleAspectFit }
                    .placeholder {
                        if let state = lastRegularImageState, state.url == url {
                            Image(uiImage: state.image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Color.gray.opacity(0.1)
                                .frame(height: 200)
                                .clipShape(.rect(cornerRadius: 8))
                        }
                    }
                    .onSuccess { result in
                        lastRegularImageState = RegularImageState(url: url, image: result.image)
                    }
                    .onFailure { error in
                        guard !error.isTaskCancelled else { return }
                        logger.warning("Image fetch failed for \(url?.absoluteString ?? "nil", privacy: .public): \(error.localizedDescription, privacy: .public)")
                    }
                    .fade(duration: 0)
                    .cacheMemoryOnly(!shouldCache)
                    .forceRefresh(shouldCache ? false : true)
                    .cacheOriginalImage(!shouldCache ? false : true)
                    .id(shouldCache ? url?.absoluteString : "\(url?.absoluteString ?? "")-\(forceRefreshKey)")
                    .frame(maxHeight: 300)
                    .clipShape(.rect(cornerRadius: 8))
            } else {
                KFImage(url)
                    .withOpenHABCredentials(for: networkTracker.activeConnection)
                    .setProcessor(OpenHABImageProcessor(svgMaxSize: nil))
                    .placeholder {
                        if let state = lastRegularImageState, state.url == url {
                            Image(uiImage: state.image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Color.gray.opacity(0.1)
                                .frame(height: 200)
                                .clipShape(.rect(cornerRadius: 8))
                        }
                    }
                    .onSuccess { result in
                        lastRegularImageState = RegularImageState(url: url, image: result.image)
                    }
                    .onFailure { error in
                        guard !error.isTaskCancelled else { return }
                        logger.warning("Image fetch failed for \(url?.absoluteString ?? "nil", privacy: .public): \(error.localizedDescription, privacy: .public)")
                    }
                    .fade(duration: 0)
                    .resizable()
                    .cacheMemoryOnly(!shouldCache)
                    .forceRefresh(shouldCache ? false : true)
                    .cacheOriginalImage(!shouldCache ? false : true)
                    .id(shouldCache ? url?.absoluteString : "\(url?.absoluteString ?? "")-\(forceRefreshKey)")
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(.rect(cornerRadius: 8))
            }
        case .empty:
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 200)
                .overlay(
                    Text("No Image URL")
                        .foregroundStyle(.secondary)
                )
                .clipShape(.rect(cornerRadius: 8))
        }
    }

    private func setupRefreshTimer() {
        stopRefreshTimer()

        // Chart widgets should refresh from incoming sitemap updates to stay aligned
        // with server state transitions (e.g. period switch visibility changes).
        // A separate local timer can race with those updates and intermittently show lag.
        guard !isChartByMediaKind else {
            return
        }

        guard input.refresh != 0 else { return }

        let refreshInterval = TimeInterval(Double(input.refresh) / 1000)
        guard refreshInterval > 0.09 else { return }

        logger.info("Scheduling image refresh every \(refreshInterval) seconds")
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            Task { @MainActor in
                logger.info("Refreshing image on \(refreshInterval) seconds schedule")
                forceRefreshKey = UUID()
            }
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func syncChartDisplayURL() {
        guard isChartByMediaKind else {
            chartDisplayState = nil
            return
        }

        let currentChartKey = makeChartDisplayKey()
        switch input.imageDescriptor.resolveImagePayload(rootUrl: viewModel.openHABRootUrl ?? "", chartStyle: chartStyle) {
        case let .link(url):
            chartDisplayState = ChartDisplayState(key: currentChartKey, url: url)
        case .embedded, .empty:
            chartDisplayState = ChartDisplayState(key: currentChartKey, url: nil)
        }
    }

    private func makeChartDisplayKey() -> String {
        let themeKey = switch chartStyle {
        case .dark: "dark"
        case .light: "light"
        }
        let rootKey = viewModel.openHABRootUrl ?? ""
        return "\(input.widgetId)|\(input.imageDescriptor.period)|\(themeKey)|\(rootKey)"
    }
}

struct ImageRowView: View {
    let input: MediaRowInput
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        makeImageRowContent(
            ImageRowConfig(
                input: input,
                viewModel: viewModel
            )
        )
    }
}
