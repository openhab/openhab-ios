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
import CommonUI
import Kingfisher
import OpenHABCore
import os.log
import SFSafeSymbols
import SwiftUI

/// Forces KFImage recreation after the app returns from an extended background period.
///
/// When iOS evicts Kingfisher's in-memory cache under memory pressure, KFImage instances
/// whose `.id()` hasn't changed are never recreated and therefore never re-fetch their
/// images. This coordinator increments `reloadEpoch` after the app has been in the
/// background for longer than `reloadThreshold`, which is included in each KFImage's
/// `.id()` so that a fresh load from the Kingfisher disk cache is triggered automatically.
@MainActor
final class IconReloadCoordinator: ObservableObject {
    static let shared = IconReloadCoordinator()
    static let reloadThreshold: TimeInterval = 60

    @Published private(set) var reloadEpoch: Int = 0

    private var backgroundedAt: Date?

    init(observeNotifications: Bool = true) {
        guard observeNotifications else { return }
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didEnterBackgroundNotification) {
                self?.didEnterBackground()
            }
        }
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                self?.didBecomeActive()
            }
        }
    }

    func didEnterBackground(now: Date = Date()) {
        backgroundedAt = now
    }

    func didBecomeActive(now: Date = Date()) {
        guard let backgroundedAt else { return }
        self.backgroundedAt = nil
        if now.timeIntervalSince(backgroundedAt) >= Self.reloadThreshold {
            reloadEpoch += 1
        }
    }
}

/// Thread-safe actor for tracking cached icon keys
actor IconCacheTracker {
    static let shared = IconCacheTracker()
    private var cachedKeys: [String] = []

    func addCacheKey(_ key: String) {
        if !cachedKeys.contains(key) {
            cachedKeys.append(key)
        }
    }

    func getCachedKeys() -> [String] {
        cachedKeys
    }

    func clearCache() {
        cachedKeys.removeAll()
    }

    func getCacheCount() -> Int {
        cachedKeys.count
    }
}

struct IconInputView: View {
    let input: RowIconInput
    let rowIdentity: String
    let fallbackSymbol: SFSymbol?
    @ObservedObject private var networkTracker = MainActorNetworkTracker.shared
    @ObservedObject private var iconReloader = IconReloadCoordinator.shared
    @Environment(\.colorScheme) private var colorScheme

    let size: CGSize
    let iconType: IconType = .svg

    private let logger = Logger(subsystem: "org.openhab", category: "IconInputView")

    @State private var currentImage: UIImage?

    private var iconColorHex: String {
        let logicColor = !input.iconColor.isEmpty ? UIColor(fromString: input.iconColor) : .ohBlack
        return logicColor.semanticColorToHex() ?? "#000000"
    }

    private var iconURL: URL? {
        guard input.showIcon, !input.icon.isEmpty else { return nil }

        guard
            let activeConnection = networkTracker.activeConnection,
            !activeConnection.configuration.url.isEmpty else {
            recordIconResolutionFailure(
                reason: networkTracker.activeConnection == nil ? "no-active-connection" : "empty-connection-url",
                connectionDescription: networkTracker.activeConnection?.configuration.publicLogDescription ?? "none"
            )
            logger.debug("No active connection to fetch icon")
            return nil
        }

        guard let endpoint = Endpoint.icon(
            rootUrl: activeConnection.configuration.url,
            version: activeConnection.version,
            icon: input.icon,
            state: input.iconState,
            iconType: iconType,
            iconColor: iconColorHex,
            staticIcon: input.staticIcon
        )?.url else {
            recordIconResolutionFailure(
                reason: "endpoint-url-build-failed",
                connectionDescription: activeConnection.configuration.publicLogDescription
            )
            return nil
        }
        return endpoint
    }

    var body: some View {
        ZStack {
            if let fallbackSymbol, currentImage == nil {
                Image(systemSymbol: fallbackSymbol)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width * 0.75, height: size.height * 0.75)
                    .foregroundStyle(.primary)
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: size.width, height: size.height)
            }

            if let iconURL {
                KFImage(iconURL)
                    .withOpenHABCredentials(for: networkTracker.activeConnection)
                    .retry(maxCount: 3, interval: .seconds(5))
                    .resizable()
                    .setProcessor(OpenHABImageProcessor(iconColor: processorIconColor(for: iconURL)))
                    .onFailure { error in
                        guard !error.isTaskCancelled else {
                            recordIconCancellation(url: iconURL)
                            return
                        }
                        recordIconFailure(url: iconURL, reason: error.localizedDescription)
                        logger.error("Icon loading failed for icon '\(input.icon, privacy: .public)': \(error.localizedDescription, privacy: .public)")
                        logger.error("Failed URL: \(iconURL.absoluteString, privacy: .public)")
                    }
                    .onSuccess { result in
                        currentImage = result.image
                        recordIconSuccess(url: iconURL, cacheType: result.cacheType)
                        if result.cacheType != .none {
                            let cacheKey = iconURL.absoluteString
                            Task {
                                await IconCacheTracker.shared.addCacheKey(cacheKey)
                            }
                        }
                    }
                    .placeholder { _ in
                        Image(uiImage: currentImage ?? .init()).resizable()
                    }
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
                    .id("\(iconURL.absoluteString)-\(colorScheme)-\(iconReloader.reloadEpoch)")
                    .onAppear {
                        recordIconStart(url: iconURL)
                    }
            }
        }
    }

    init(input: RowIconInput, rowIdentity: String, size: CGSize, fallbackSymbol: SFSymbol? = nil) {
        self.input = input
        self.rowIdentity = rowIdentity
        self.size = size
        self.fallbackSymbol = fallbackSymbol
    }

    private func processorIconColor(for url: URL) -> String? {
        guard url.host != "api.iconify.design" else { return nil }
        return iconColorHex
    }

    private func recordIconStart(url: URL) {
        guard SitemapDiagnostics.isEnabled else { return }
        SitemapDiagnostics.logIconStart(
            rowIdentity: rowIdentity,
            icon: input.icon,
            url: url,
            cacheKey: url.absoluteString
        )
        Task {
            await IconLoadDiagnostics.shared.recordStart(url: url, rowIdentity: rowIdentity)
        }
    }

    private func recordIconSuccess(url: URL, cacheType: CacheType) {
        guard SitemapDiagnostics.isEnabled else { return }
        SitemapDiagnostics.logIconSuccess(
            rowIdentity: rowIdentity,
            icon: input.icon,
            url: url,
            cacheType: cacheType.diagnosticsName
        )
        Task {
            await IconLoadDiagnostics.shared.recordSuccess(
                url: url,
                rowIdentity: rowIdentity,
                cacheType: cacheType.diagnosticsName
            )
        }
    }

    private func recordIconCancellation(url: URL) {
        guard SitemapDiagnostics.isEnabled else { return }
        SitemapDiagnostics.logIconFailure(
            rowIdentity: rowIdentity,
            icon: input.icon,
            url: url,
            reason: "task-cancelled",
            cancelled: true
        )
        Task {
            await IconLoadDiagnostics.shared.recordCancellation(url: url, rowIdentity: rowIdentity)
        }
    }

    private func recordIconFailure(url: URL, reason: String) {
        guard SitemapDiagnostics.isEnabled else { return }
        SitemapDiagnostics.logIconFailure(
            rowIdentity: rowIdentity,
            icon: input.icon,
            url: url,
            reason: reason,
            cancelled: false
        )
        Task {
            await IconLoadDiagnostics.shared.recordFailure(url: url, rowIdentity: rowIdentity)
        }
    }

    private func recordIconResolutionFailure(reason: String, connectionDescription: String) {
        guard SitemapDiagnostics.isEnabled else { return }
        SitemapDiagnostics.logIconResolutionFailure(
            rowIdentity: rowIdentity,
            icon: input.icon,
            reason: reason,
            trackerStatus: networkTracker.status.rawValue,
            connectionDescription: connectionDescription
        )
        Task {
            await IconLoadDiagnostics.shared.recordResolutionFailure(rowIdentity: rowIdentity)
        }
    }
}

/// A SwiftUI view that displays widget icons with openHAB-specific styling and caching
struct IconView: View {
    @ObservedObject var widget: OpenHABWidget
    @ObservedObject private var networkTracker = MainActorNetworkTracker.shared
    @ObservedObject private var iconReloader = IconReloadCoordinator.shared
    @Environment(\.colorScheme) private var colorScheme

    let size: CGSize
    let iconType: IconType = .svg
    /// Optional SF Symbol to show as fallback when network icon is unavailable (useful for previews)
    let fallbackSymbol: SFSymbol?

    private let logger = Logger(subsystem: "org.openhab", category: "IconView")

    @State private var currentImage: UIImage?

    /// Icon color converted to hex, using ohBlack as default (adapts to light/dark mode)
    private var iconColorHex: String {
        let logicColor = !widget.iconColor.isEmpty ? UIColor(fromString: widget.iconColor) : .ohBlack
        return logicColor.semanticColorToHex() ?? "#000000"
    }

    private var iconURL: URL? {
        guard !widget.icon.isEmpty else { return nil }

        guard
            let activeConnection = networkTracker.activeConnection,
            !activeConnection.configuration.url.isEmpty else {
            recordIconResolutionFailure(
                reason: networkTracker.activeConnection == nil ? "no-active-connection" : "empty-connection-url",
                connectionDescription: networkTracker.activeConnection?.configuration.publicLogDescription ?? "none"
            )
            logger.debug("No active connection to fetch icon")
            return nil
        }

        guard let endpoint = Endpoint.icon(
            rootUrl: activeConnection.configuration.url,
            version: activeConnection.version,
            icon: widget.icon,
            state: widget.iconState(),
            iconType: iconType,
            iconColor: iconColorHex,
            staticIcon: widget.staticIcon
        )?.url else {
            recordIconResolutionFailure(
                reason: "endpoint-url-build-failed",
                connectionDescription: activeConnection.configuration.publicLogDescription
            )
            return nil
        }
        return endpoint
    }

    var body: some View {
        ZStack {
            // No icon URL - show fallback symbol if available
            if let fallbackSymbol {
                Image(systemSymbol: fallbackSymbol)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width * 0.75, height: size.height * 0.75)
                    .foregroundStyle(.primary)
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: size.width, height: size.height)
            }

            if let iconURL {
                KFImage(iconURL)
                    .withOpenHABCredentials(for: networkTracker.activeConnection)
                    .retry(maxCount: 3, interval: .seconds(5))
                    .resizable()
                    .setProcessor(OpenHABImageProcessor(iconColor: processorIconColor(for: iconURL)))
                    .onFailure { error in
                        guard !error.isTaskCancelled else {
                            recordIconCancellation(url: iconURL)
                            return
                        }
                        recordIconFailure(url: iconURL, reason: error.localizedDescription)
                        logger.error("Icon loading failed for icon '\(widget.icon, privacy: .public)': \(error.localizedDescription, privacy: .public)")
                        logger.error("Failed URL: \(iconURL.absoluteString, privacy: .public)")
                    }
                    .onSuccess { result in
                        currentImage = result.image
                        recordIconSuccess(url: iconURL, cacheType: result.cacheType)
                        if result.cacheType != .none {
                            let cacheKey = iconURL.absoluteString
                            Task {
                                await IconCacheTracker.shared.addCacheKey(cacheKey)
                            }
                        }
                    }
                    .placeholder { _ in
                        // Workaround to show current image before new image is displayed. See https://github.com/onevcat/Kingfisher/issues/2028
                        Image(uiImage: currentImage ?? .init()).resizable()
                    }
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
                    .id("\(iconURL.absoluteString)-\(colorScheme)-\(iconReloader.reloadEpoch)")
                    .onAppear {
                        recordIconStart(url: iconURL)
                    }
            }
        }
    }

    /// Returns the icon color for SVG preprocessing, or nil for iconify icons (they handle their own colors)
    private func processorIconColor(for url: URL) -> String? {
        // Don't apply color preprocessing for iconify icons
        guard url.host != "api.iconify.design" else { return nil }
        return iconColorHex
    }

    private func recordIconStart(url: URL) {
        guard SitemapDiagnostics.isEnabled else { return }
        SitemapDiagnostics.logIconStart(
            rowIdentity: widget.id,
            icon: widget.icon,
            url: url,
            cacheKey: url.absoluteString
        )
        Task {
            await IconLoadDiagnostics.shared.recordStart(url: url, rowIdentity: widget.id)
        }
    }

    private func recordIconSuccess(url: URL, cacheType: CacheType) {
        guard SitemapDiagnostics.isEnabled else { return }
        SitemapDiagnostics.logIconSuccess(
            rowIdentity: widget.id,
            icon: widget.icon,
            url: url,
            cacheType: cacheType.diagnosticsName
        )
        Task {
            await IconLoadDiagnostics.shared.recordSuccess(
                url: url,
                rowIdentity: widget.id,
                cacheType: cacheType.diagnosticsName
            )
        }
    }

    private func recordIconCancellation(url: URL) {
        guard SitemapDiagnostics.isEnabled else { return }
        SitemapDiagnostics.logIconFailure(
            rowIdentity: widget.id,
            icon: widget.icon,
            url: url,
            reason: "task-cancelled",
            cancelled: true
        )
        Task {
            await IconLoadDiagnostics.shared.recordCancellation(url: url, rowIdentity: widget.id)
        }
    }

    private func recordIconFailure(url: URL, reason: String) {
        guard SitemapDiagnostics.isEnabled else { return }
        SitemapDiagnostics.logIconFailure(
            rowIdentity: widget.id,
            icon: widget.icon,
            url: url,
            reason: reason,
            cancelled: false
        )
        Task {
            await IconLoadDiagnostics.shared.recordFailure(url: url, rowIdentity: widget.id)
        }
    }

    private func recordIconResolutionFailure(reason: String, connectionDescription: String) {
        guard SitemapDiagnostics.isEnabled else { return }
        SitemapDiagnostics.logIconResolutionFailure(
            rowIdentity: widget.id,
            icon: widget.icon,
            reason: reason,
            trackerStatus: networkTracker.status.rawValue,
            connectionDescription: connectionDescription
        )
        Task {
            await IconLoadDiagnostics.shared.recordResolutionFailure(rowIdentity: widget.id)
        }
    }
}

// MARK: - Convenience Extensions

private extension CacheType {
    var diagnosticsName: String {
        switch self {
        case .memory:
            "memory"
        case .disk:
            "disk"
        case .none:
            "none"
        }
    }
}

extension IconView {
    /// Creates a widget icon view with standard size (32x32, matching UIKit cells)
    init(widget: OpenHABWidget, fallbackSymbol: SFSymbol? = nil) {
        self.init(
            widget: widget,
            size: CGSize(width: 32, height: 32),
            fallbackSymbol: fallbackSymbol
        )
    }
}

// MARK: - Widget Type Extensions

extension IconView {
    /// Determines if a widget type should show an icon (equivalent to NoIconDisplayableCell protocol)
    static func shouldShowIcon(for widget: OpenHABWidget) -> Bool {
        // These widget types should not show icons (equivalent to NoIconDisplayableCell)
        switch widget.type {
        case .frame, .image, .chart, .video, .webview:
            false
        default:
            !widget.icon.isEmpty
        }
    }
}

#Preview {
    let widget = OpenHABWidget()
    widget.icon = "switch"
    widget.label = "Test Switch"
    return IconView(widget: widget, fallbackSymbol: .switch2)
}
