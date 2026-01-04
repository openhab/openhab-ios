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

/// A SwiftUI view that displays widget icons with openHAB-specific styling and caching
struct IconView: View {
    @ObservedObject var widget: OpenHABWidget
    @ObservedObject private var networkTracker = MainActorNetworkTracker.shared
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var viewModel: SitemapPageViewModel

    let size: CGSize
    let iconType: IconType = .svg

    private let logger = Logger(subsystem: "org.openhab", category: "IconView")

    @State private var currentImage: UIImage?

    private var iconURL: URL? {
        guard !widget.icon.isEmpty else { return nil }

        guard
            let activeConnection = networkTracker.activeConnection,
            !activeConnection.configuration.url.isEmpty else {
            logger.debug("No active connection to fetch icon")
            return nil
        }

        var queriedIconColor: String {
            switch colorScheme {
            case .light:
                return widget.iconColor.isEmpty ? "black" : widget.iconColor
            case .dark:
                return widget.iconColor.isEmpty ? "white" : widget.iconColor
            @unknown default:
                return widget.iconColor.isEmpty ? "black" : widget.iconColor
            }
        }

        return Endpoint.icon(
            rootUrl: activeConnection.configuration.url,
            version: activeConnection.version,
            icon: widget.icon,
            state: widget.iconState(),
            iconType: iconType,
            iconColor: queriedIconColor,
            staticIcon: widget.staticIcon
        )?.url
    }

    var body: some View {
        ZStack {
            // No icon or failed to load - show empty space
            Rectangle()
                .fill(Color.clear)
                .frame(width: size.width, height: size.height)

            if let iconURL {
                KFImage(iconURL)
                    .retry(maxCount: 3, interval: .seconds(5))
                    .resizable()
                    .setProcessor(OpenHABImageProcessor())
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
                    .id(viewModel.pageId + widget.id)
            }
        }
    }
}

// MARK: - Convenience Extensions

extension IconView {
    /// Creates a widget icon view with standard size
    init(widget: OpenHABWidget) {
        self.init(
            widget: widget,
            size: CGSize(width: 24, height: 24)
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
    return IconView(widget: widget)
}
