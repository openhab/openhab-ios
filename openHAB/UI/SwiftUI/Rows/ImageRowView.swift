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
import SFSafeSymbols
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
    @State private var animatedGIFSourceURL: URL?
    @State private var embeddedGIFAspectRatio: CGFloat = 16.0 / 9.0
    @State private var imageLoadError: KingfisherError?

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
        .onChange(of: input.url) {
            animatedGIFSourceURL = nil
            imageLoadError = nil
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
            .frame(maxWidth: .infinity)
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
            // swiftlint:disable:next redundant_discardable_let
            let _ = logger.info("ImageRow embedded: \(data.count, privacy: .public) bytes, isGIF=\(isGIFMagic(data), privacy: .public)")
            if isGIFMagic(data) {
                KFAnimatedImage(source: .provider(provider))
                    .withOpenHABCredentials(for: networkTracker.activeConnection)
                    .configure { $0.contentMode = .scaleAspectFit }
                    .onSuccess { result in
                        let size = result.image.size
                        if size.height > 0 { embeddedGIFAspectRatio = size.width / size.height }
                    }
                    .animatedGIFFrame(aspectRatio: embeddedGIFAspectRatio)
                    .clipShape(.rect(cornerRadius: 8))
            } else {
                KFImage(source: .provider(provider))
                    .withOpenHABCredentials(for: networkTracker.activeConnection)
                    .setProcessor(OpenHABImageProcessor(svgMaxSize: nil))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: 8))
            }
        case let .link(url):
            if let error = imageLoadError {
                imageErrorView(for: error)
            } else if animatedGIFSourceURL == url {
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
                        imageLoadError = nil
                        lastRegularImageState = RegularImageState(url: url, image: result.image)
                    }
                    .onFailure { error in
                        guard !error.isTaskCancelled else { return }
                        logger.warning("Image fetch failed for \(url?.absoluteString ?? "nil", privacy: .public): \(error.localizedDescription, privacy: .public)")
                        imageLoadError = error
                    }
                    .fade(duration: 0)
                    .cacheMemoryOnly(!shouldCache)
                    .forceRefresh(shouldCache ? false : true)
                    .cacheOriginalImage(!shouldCache ? false : true)
                    .id(shouldCache ? url?.absoluteString : "\(url?.absoluteString ?? "")-\(forceRefreshKey)")
                    .animatedGIFFrame(aspectRatio: aspectRatio(forGIFAt: url))
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
                        imageLoadError = nil
                        logger.info("Image fetch successful for \(url?.absoluteString ?? "nil", privacy: .public)")
                        lastRegularImageState = RegularImageState(url: url, image: result.image)
                        if isGIF(result) {
                            logger.debug("GIF detected for \(url?.absoluteString ?? "nil", privacy: .public)")
                            animatedGIFSourceURL = url
                        }
                    }
                    .onFailure { error in
                        guard !error.isTaskCancelled else { return }
                        logger.warning("Image fetch failed for \(url?.absoluteString ?? "nil", privacy: .public): \(error.localizedDescription, privacy: .public)")
                        imageLoadError = error
                    }
                    .fade(duration: 0)
                    .resizable()
                    .cacheMemoryOnly(!shouldCache)
                    .forceRefresh(shouldCache ? false : true)
                    .cacheOriginalImage(!shouldCache ? false : true)
                    .id(shouldCache ? url?.absoluteString : "\(url?.absoluteString ?? "")-\(forceRefreshKey)")
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
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

    private func aspectRatio(forGIFAt url: URL?) -> CGFloat {
        guard let state = lastRegularImageState, state.url == url, state.image.size.height > 0 else {
            return 16.0 / 9.0
        }
        return state.image.size.width / state.image.size.height
    }

    private func isGIFMagic(_ data: Data) -> Bool {
        data.count >= 3 && data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46 // "GIF"
    }

    private func isGIF(_ result: RetrieveImageResult) -> Bool {
        if let frameCount = result.image.kf.imageFrameCount, frameCount > 1 {
            return true
        }
        return result.data().map(isGIFMagic) ?? false
    }

    private func imageErrorView(for error: KingfisherError) -> some View {
        VStack(spacing: 8) {
            Image(systemSymbol: .exclamationmarkTriangle)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(describeImageError(error))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func describeImageError(_ error: KingfisherError) -> String {
        if case let .responseError(reason) = error,
           case let .invalidHTTPStatusCode(response) = reason {
            switch response.statusCode {
            case 401: return "Authentication required (HTTP 401)"
            case 403: return "Access denied (HTTP 403)"
            case 404: return "Image not found (HTTP 404)"
            case 500...: return "Server error (HTTP \(response.statusCode))"
            default: return "HTTP error \(response.statusCode)"
            }
        }
        return error.localizedDescription
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

private struct AnimatedGIFFrameModifier: ViewModifier {
    let aspectRatio: CGFloat
    @State private var availableWidth: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .frame(
                width: availableWidth > 0 ? availableWidth : nil,
                height: availableWidth > 0 ? availableWidth / aspectRatio : nil
            )
            .contentMargins(.horizontal, 0, for: .scrollContent)
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { newWidth in
                guard newWidth > 0 else { return }
                availableWidth = newWidth
            }
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

private extension View {
    func animatedGIFFrame(aspectRatio: CGFloat) -> some View {
        modifier(AnimatedGIFFrameModifier(aspectRatio: aspectRatio))
    }
}
