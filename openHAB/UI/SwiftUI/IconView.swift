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
import Kingfisher
import OpenHABCore
import os.log
import SFSafeSymbols
import SwiftUI

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

private struct SitemapPageIdentityKey: EnvironmentKey {
    static let defaultValue = ""
}

extension EnvironmentValues {
    var sitemapPageIdentity: String {
        get { self[SitemapPageIdentityKey.self] }
        set { self[SitemapPageIdentityKey.self] = newValue }
    }
}

struct IconInputView: View {
    let input: RowIconInput
    let rowIdentity: String
    let fallbackSymbol: SFSymbol?
    @ObservedObject private var networkTracker = MainActorNetworkTracker.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sitemapPageIdentity) private var pageIdentity
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
            logger.debug("No active connection to fetch icon")
            return nil
        }

        return Endpoint.icon(
            rootUrl: activeConnection.configuration.url,
            version: activeConnection.version,
            icon: input.icon,
            state: input.iconState,
            iconType: iconType,
            iconColor: iconColorHex,
            staticIcon: input.staticIcon
        )?.url
    }

    var body: some View {
        let _ = SitemapDiagnostics.logRender(kind: "iconInput", identity: "\(pageIdentity)|\(rowIdentity)", detail: input.icon)
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
                    .retry(maxCount: 3, interval: .seconds(5))
                    .resizable()
                    .setProcessor(OpenHABImageProcessor(iconColor: processorIconColor(for: iconURL)))
                    .onFailure { error in
                        logger.error("Icon loading failed: \(error.localizedDescription)")
                        logger.error("Failed URL: \(iconURL.absoluteString)")
                    }
                    .onSuccess { result in
                        currentImage = result.image
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
                    .cancelOnDisappear(true)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
                    .id("\(pageIdentity)-\(rowIdentity)-\(colorScheme)")
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
}

/// A SwiftUI view that displays widget icons with openHAB-specific styling and caching
struct IconView: View {
    @ObservedObject var widget: OpenHABWidget
    @ObservedObject private var networkTracker = MainActorNetworkTracker.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sitemapPageIdentity) private var pageIdentity
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
            logger.debug("No active connection to fetch icon")
            return nil
        }

        return Endpoint.icon(
            rootUrl: activeConnection.configuration.url,
            version: activeConnection.version,
            icon: widget.icon,
            state: widget.iconState(),
            iconType: iconType,
            iconColor: iconColorHex,
            staticIcon: widget.staticIcon
        )?.url
    }

    var body: some View {
        let _ = SitemapDiagnostics.logRender(kind: "iconWidget", identity: "\(pageIdentity)|\(widget.id)", detail: widget.icon)
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
                    .retry(maxCount: 3, interval: .seconds(5))
                    .resizable()
                    .setProcessor(OpenHABImageProcessor(iconColor: processorIconColor(for: iconURL)))
                    .onFailure { error in
                        logger.error("Icon loading failed for widget \(widget.label): \(error.localizedDescription)")
                        logger.error("Failed URL: \(iconURL.absoluteString)")
                    }
                    .onSuccess { result in
                        currentImage = result.image
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
                    .cancelOnDisappear(true)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
                    .id("\(pageIdentity)-\(widget.id)-\(colorScheme)")
            }
        }
    }

    /// Returns the icon color for SVG preprocessing, or nil for iconify icons (they handle their own colors)
    private func processorIconColor(for url: URL) -> String? {
        // Don't apply color preprocessing for iconify icons
        guard url.host != "api.iconify.design" else { return nil }
        return iconColorHex
    }
}

// MARK: - Convenience Extensions

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
        .environmentObject(SitemapPageViewModel())
}
