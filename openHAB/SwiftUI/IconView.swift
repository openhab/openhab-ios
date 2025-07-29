// Copyright (c) 2010-2025 Contributors to the openHAB project
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
    @ObservedObject private var networkTracker = NetworkTracker.shared
    @Environment(\.colorScheme) private var colorScheme

    let size: CGSize
    let iconType: IconType = .svg

    private let logger = Logger(subsystem: "org.openhab", category: "IconView")

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
        logger.debug("icon color: \(queriedIconColor)")

        return Endpoint.icon(
            rootUrl: activeConnection.configuration.url,
            version: activeConnection.version,
            icon: widget.icon,
            state: widget.iconState(),
            iconType: iconType,
            iconColor: queriedIconColor,
            staticIcon: widget.staticIcon
        ).url
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
                    }
                    .onSuccess { result in
                        logger.debug("Loading of icon succeeded for widget \(widget.label)")
                        if result.cacheType != .none {
                            let cacheKey = iconURL.absoluteString
                            Task {
                                await IconCacheTracker.shared.addCacheKey(cacheKey)
                            }
                            logger.debug("Icon loaded from cache: \(cacheKey)")
                        }
                    }
                    .fade(duration: 0.25)
                    .cancelOnDisappear(true)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
            }
        }
        .onChange(of: networkTracker.activeConnection) { _ in
        }
    }
}

// MARK: - Convenience Extensions

extension IconView {
    /// Creates a widget icon view with standard size and default styling or custom icon color
    init(widget: OpenHABWidget) {
        self.init(
            widget: widget,
            size: CGSize(width: 24, height: 24)
        )
    }

    init(icon: String, iconColor: String = "primary") {
        let widget = OpenHABWidget(icon: icon, iconColor: iconColor)
        self.init(widget: widget)
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
