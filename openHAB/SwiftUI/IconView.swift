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
    @ObservedObject private var networkTracker = NetworkTracker.shared
    @Environment(\.colorScheme) private var colorScheme

    let size: CGSize
    let iconType: IconType = .svg

    @State private var imageLoadingFailed = false
    @State private var retryCount = 0
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 1.0

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetIconView")

    private var iconURL: URL? {
        guard !widget.icon.isEmpty,
              let activeConnection = networkTracker.activeConnection,
              !activeConnection.configuration.url.isEmpty else {
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
            iconColor: queriedIconColor
        ).url
    }

    var body: some View {
        ZStack {
            // No icon or failed to load - show empty space
            Rectangle()
                .fill(Color.clear)
                .frame(width: size.width, height: size.height)

            if let iconURL, !imageLoadingFailed {
                KFImage.url(iconURL)
                    .placeholder {
                        // Show empty space while loading
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: size.width, height: size.height)
                    }
                    .onFailure { error in
                        logger.error("Icon loading failed for widget \(widget.label): \(error.localizedDescription)")
//                        handleLoadingFailure()
                        imageLoadingFailed = true
                    }
                    .onSuccess { _ in
                        imageLoadingFailed = false
                        retryCount = 0
                    }
                    .setProcessor(OpenHABImageProcessor())
                    .fade(duration: 0.25)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
                    .id(iconURL.absoluteString)
            }
        }
        .onChange(of: widget.icon) { _ in
            // Reset loading state when icon changes
            resetLoadingState()
        }
        .onChange(of: widget.iconState()) { _ in
            // Reset loading state when icon state changes
            resetLoadingState()
        }
        .onChange(of: networkTracker.activeConnection) { _ in
            // Reset loading state when connection changes
            resetLoadingState()
        }
    }

    private func handleLoadingFailure() {
        if retryCount < maxRetries {
            retryCount += 1
            logger.info("Retrying icon load for widget \(widget.label), attempt \(retryCount)/\(maxRetries)")

            DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay * Double(retryCount)) {
                // Force reload by toggling imageLoadingFailed
                imageLoadingFailed = false
            }
        } else {
            logger.warning("Max retries reached for widget \(widget.label), giving up")
            imageLoadingFailed = true
        }
    }

    private func resetLoadingState() {
        imageLoadingFailed = false
        retryCount = 0
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
