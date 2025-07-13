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

import Kingfisher
import OpenHABCore
import os.log
import SwiftUI

/// A SwiftUI view that displays widget icons with openHAB-specific styling and caching
struct IconView: View {
    @ObservedObject var widget: OpenHABWidget
    @Environment(\.colorScheme) private var colorScheme

    let size: CGSize
    let iconType: IconType = .svg

    @State private var imageLoadingFailed = false

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetIconView")

    private var iconURL: URL? {
        guard !widget.icon.isEmpty else { return nil }

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
            rootUrl: NetworkTracker.shared.activeConnection?.configuration.url ?? "",
            version: NetworkTracker.shared.activeConnection?.version ?? 2,
            icon: widget.icon,
            state: widget.iconState(),
            iconType: iconType,
            iconColor: queriedIconColor
        ).url
    }

    var body: some View {
        Group {
            if let iconURL, !imageLoadingFailed {
                KFImage(iconURL)
                    .placeholder {
                        // Show empty space while loading
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: size.width, height: size.height)
                    }
                    .onFailure { error in
                        logger.error("Icon loading failed for widget \(widget.label): \(error.localizedDescription)")
                        imageLoadingFailed = true
                    }
                    .onSuccess { _ in
                        imageLoadingFailed = false
                    }
                    .setProcessor(OpenHABImageProcessor())
                    .fade(duration: 0.25)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
                    .id(iconURL.absoluteString)
            } else {
                // No icon or failed to load - show empty space
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: size.width, height: size.height)
            }
        }
        .onChange(of: widget.icon) { _ in
            // Reset loading state when icon changes
            imageLoadingFailed = false
        }
        .onChange(of: widget.iconState()) { _ in
            // Reset loading state when icon state changes
            imageLoadingFailed = false
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
