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

import Foundation
import Kingfisher
import os.log
import SDWebImageSVGCoder
import SFSafeSymbols

public struct OpenHABImageProcessor: ImageProcessor {
    // `identifier` should be the same for processors with the same properties/functionality
    // It will be used when storing and retrieving the image to/from cache.
    public let identifier: String
    private let logger = Logger(subsystem: "org.openhab", category: "OpenHABImageProcessor")

    /// - Parameter tint: The tint color used to tint the input image.
    public init() {
        identifier = "org.openhab.svgprocessor"
    }

    /// Execute `body` on the main thread synchronously, but avoid deadlock when already on main.
    @inline(__always)
    private func mainSync<T: Sendable>(_ body: @Sendable () -> T) -> T {
        if Thread.isMainThread {
            // We *are* on main; it's now safe to assert MainActor context if you want.
            MainActor.assumeIsolated { body() }
        } else {
            DispatchQueue.main.sync {
                body()
            }
        }
    }

    /// Decode SVG on the main thread (UIGraphics-based), with sane defaults.
    private func decodeSVGOnMain(_ data: Data) -> UIImage? {
        mainSync {
            SDImageSVGCoder.shared.decodedImage(
                with: data,
                options: nil
            )
        }
    }

    /// Convenience fallback symbol (orange triangle), always original rendering.
    private func warningSymbol() -> UIImage {
        let img = UIImage(systemSymbol: .exclamationmarkTriangle)
        return img.withTintColor(.orange, renderingMode: .alwaysOriginal)
    }

    // Convert input data/image to target image and return it.
    public func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        switch item {
        case let .image(image):
            logger.info("already an image")
            return image
        case let .data(data):
            guard !data.isEmpty else { return nil }

            if isSVG(data: data) {
                if let image = decodeSVGOnMain(data) {
                    let size = image.size
                    if size.width > 1000 || size.height > 1000 {
                        logger.warning("SVG decoded to very large bitmap: \(size.width, privacy: .public)x\(size.height, privacy: .public)")
                        return warningSymbol()
                    }
                    return image
                } else {
                    return warningSymbol()
                }
            } else {
                return Kingfisher.DefaultImageProcessor().process(item: item, options: KingfisherParsedOptionsInfo(KingfisherManager.shared.defaultOptions))
            }
        }
    }

    private func isSVG(data: Data?) -> Bool {
        guard let data else { return false }
        if let start = String(data: data.prefix(200), encoding: .utf8) {
            return start.contains("<svg") || start.hasPrefix("<?xml")
        }
        return false
    }
}
