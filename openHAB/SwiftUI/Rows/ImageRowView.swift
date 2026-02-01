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

struct ImageRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var viewModel: SitemapPageViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var refreshTimer: Timer?
    @State private var forceRefreshKey = UUID()

    private let logger = Logger(subsystem: "org.openhab", category: "ImageRowView")

    private var imageURL: URL? {
        guard !widget.url.isEmpty else { return nil }
        return URL(string: widget.url)
    }

    private var shouldCache: Bool {
        widget.refresh == 0
    }

    private var chartStyle: ChartStyle {
        colorScheme == .light ? .light : .dark
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let labelText = widget.labelText, !labelText.isEmpty, widget.labelSource == .sitemapDefinition {
                Text(labelText)
                    .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
                    .lineLimit(1)
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
            if widget.type == .image, let labelValue = widget.labelValue, !labelValue.isEmpty {
                Text(labelValue)
                    .font(.caption)
                    .foregroundStyle(widget.valuecolor.isEmpty ? .secondary : Color(fromString: widget.valuecolor))
                    .lineLimit(1)
            }
        }
        .onAppear {
            setupRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
        .onChange(of: widget.refresh) { _ in
            setupRefreshTimer()
        }
    }

    private func setupRefreshTimer() {
        stopRefreshTimer()

        guard widget.refresh != 0 else { return }

        let refreshInterval = TimeInterval(Double(widget.refresh) / 1000)
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
