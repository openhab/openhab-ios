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
    let widget: OpenHABWidget
    let viewModel: SitemapPageViewModel
}

@MainActor
private func makeImageRowContent(_ config: ImageRowConfig) -> ImageRowContent {
    ImageRowContent(input: config.input, widget: config.widget, viewModel: config.viewModel)
}

private struct ImageRowContent: View {
    let input: MediaRowInput
    @ObservedObject var widget: OpenHABWidget
    @ObservedObject var viewModel: SitemapPageViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var refreshTimer: Timer?
    @State private var forceRefreshKey = UUID()

    private let logger = Logger(subsystem: "org.openhab", category: "ImageRowView")

    private var shouldCache: Bool {
        input.refresh == 0
    }

    private var chartStyle: ChartStyle {
        colorScheme == .light ? .light : .dark
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
            switch widget.generateImageResult(rootUrl: viewModel.openHABRootUrl ?? "", chartStyle: chartStyle) {
            case let .embedded(data: data):
                let provider = RawImageDataProvider(data: data, cacheKey: shouldCache ? widget.widgetId : "\(widget.widgetId)-\(forceRefreshKey)")
                KFImage(source: .provider(provider))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(.rect(cornerRadius: 8))
            case let .link(url):
                KFImage(url)
                    .resizable()
                    .cacheMemoryOnly(!shouldCache)
                    .forceRefresh(shouldCache ? false : true)
                    .cacheOriginalImage(!shouldCache ? false : true)
                    .id(shouldCache ? url?.absoluteString : "\(url?.absoluteString ?? "")-\(forceRefreshKey)")
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(.rect(cornerRadius: 8))
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

            // Only show labelValue for image widgets, not charts
            if widget.type == .image, let labelValue = displayState.labelValue, !labelValue.isEmpty {
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
        .onChange(of: input.refresh) { _ in
            setupRefreshTimer()
        }
    }

    private func setupRefreshTimer() {
        stopRefreshTimer()

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
}

struct ImageRowInputView: View {
    let rowID: RowID
    let input: MediaRowInput
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        if let widget = viewModel.widget(for: rowID) {
            makeImageRowContent(
                ImageRowConfig(
                    input: input,
                    widget: widget,
                    viewModel: viewModel
                )
            )
        } else {
            EmptyView()
        }
    }
}

struct ImageRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        makeImageRowContent(
            ImageRowConfig(
                input: MediaRowInput.from(widget: widget),
                widget: widget,
                viewModel: viewModel
            )
        )
    }
}
