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

import Foundation
import Kingfisher
import os.log
import SDWebImageSVGCoder
import SFSafeSymbols

public struct OpenHABImageProcessor: ImageProcessor {
    // `identifier` should be the same for processors with the same properties/functionality
    // It will be used when storing and retrieving the image to/from cache.
    public let identifier: String
    let maxSize = CGSize(width: 64, height: 64)
    let iconColor: String?

    public init(iconColor: String? = nil) {
        self.iconColor = iconColor
        if let color = iconColor, !color.isEmpty {
            identifier = "org.openhab.svgprocessor.\(color)"
        } else {
            identifier = "org.openhab.svgprocessor"
        }
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

    /// Apply color preprocessing to SVG data
    func preprocessSVG(_ data: Data) -> Data {
        guard let iconColor, !iconColor.isEmpty,
              let svgString = String(data: data, encoding: .utf8) else {
            return data
        }

        // Convert iconColor to hex format
        let uiColor = UIColor(fromString: iconColor)
        guard let hexColor = uiColor.toHex() else {
            return data
        }

        let colorString = "#\(hexColor)"
        Logger.openHABImageProcessor.debug("Preprocessing SVG with color: \(colorString)")

        // Preprocess SVG to apply color
        var processedSVG = svgString

        // Add a style to the SVG root to set color using modern Swift regex
        // Setting 'color' makes it available to 'currentColor' references
        // Setting 'fill' applies to elements without explicit fill attributes
        do {
            let svgTagRegex = /<svg[^>]*>/
            if let match = processedSVG.firstMatch(of: svgTagRegex) {
                let svgTag = String(processedSVG[match.range])

                // Check if the svg tag already has a style attribute
                if svgTag.contains("style=") {
                    // Append to existing style
                    let modifiedTag = svgTag.replacingOccurrences(
                        of: "style=\"",
                        with: "style=\"color:\(colorString);fill:\(colorString);",
                        options: .literal
                    )
                    processedSVG.replaceSubrange(match.range, with: modifiedTag)
                } else {
                    // Add new style attribute before the closing >
                    let modifiedTag = svgTag.replacingOccurrences(
                        of: ">",
                        with: " style=\"color:\(colorString);fill:\(colorString);\">",
                        options: .backwards
                    )
                    processedSVG.replaceSubrange(match.range, with: modifiedTag)
                }
            }
        }

        return processedSVG.data(using: .utf8) ?? data
    }

    /// Decode SVG on the main thread (UIGraphics-based), with sane defaults.
    private func decodeSVGOnMain(_ data: Data, targetSize: CGSize? = nil, preserveAspectRatio: Bool = true) -> UIImage? {
        mainSync {
            var options: [SDImageCoderOption: Any] = [:]

            if let size = targetSize {
                options[.decodeThumbnailPixelSize] = size
                options[.decodePreserveAspectRatio] = preserveAspectRatio
                Logger.openHABImageProcessor.debug("Setting targetSize to \(size)")
            }

            return SDImageSVGCoder.shared.decodedImage(
                with: data,
                options: options.isEmpty ? nil : options
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
            Logger.openHABImageProcessor.info("already an image")
            return image
        case let .data(data):
            guard !data.isEmpty else { return nil }

            if isSVG(data: data) {
                // Apply color preprocessing to SVG if iconColor is specified
                let processedData = preprocessSVG(data)

                // Limit SVG decode size (to prevent memory issues
                if let image = decodeSVGOnMain(processedData, targetSize: maxSize, preserveAspectRatio: true) {
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

extension CGSize: @retroactive CustomStringConvertible {
    public var description: String {
        "(\(width), \(height))"
    }
}
