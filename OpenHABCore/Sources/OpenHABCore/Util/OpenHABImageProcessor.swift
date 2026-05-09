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
#if canImport(AppKit)
import WebKit
#endif

/// An image processor for openHAB icons and images with SVG color preprocessing support.
///
/// This processor extends Kingfisher's `ImageProcessor` to handle both standard image formats
/// and SVG images. It provides special handling for SVG images by allowing dynamic color
/// modification through the `iconColor` parameter.
///
/// For SVG images, the processor:
/// - Detects and parses SVG content
/// - Applies color preprocessing to modify the SVG's color properties
/// - Limits decode size to prevent memory issues
/// - Supports `currentColor` references in SVG elements
///
/// For standard image formats (PNG, JPEG, etc.), the processor delegates to Kingfisher's
/// default image processor.
///
/// - SeeAlso: `ImageProcessor` from Kingfisher framework
public struct OpenHABImageProcessor: ImageProcessor {
    private static let defaultSVGMaxSize = CGSize(width: 64, height: 64)
    // `identifier` should be the same for processors with the same properties/functionality
    // It will be used when storing and retrieving the image to/from cache.
    public let identifier: String
    let svgMaxSize: CGSize?
    let iconColor: String?

    /// Creates a new image processor for openHAB icons and images.
    ///
    /// This processor handles both standard image formats and SVG images. For SVG images,
    /// it applies color preprocessing when an `iconColor` is specified.
    ///
    /// - Parameter iconColor: Optional color string to apply to SVG images. When provided,
    ///   the processor adds or modifies the SVG's root style attribute to set both the
    ///   `color` and `fill` properties, enabling dynamic recoloring of SVG icons.
    ///
    ///   Supported color formats:
    ///   - **Named colors**: Standard color names like `"red"`, `"blue"`, `"green"`
    ///   - **openHAB colors**: Special colors like `"primary"`, `"secondary"`
    ///   - **Hex codes**: Hexadecimal color values like `"#FF0000"` or `"FF0000"`
    ///   - **RGB strings**: Not currently supported, but the color will be converted to hex
    ///
    ///   If `nil` or empty, SVG images are processed without color modification.
    ///
    /// - Note: The color preprocessing only affects SVG images. Standard image formats
    ///   (PNG, JPEG, etc.) are processed normally without color modification.
    ///
    /// - Example:
    ///   ```swift
    ///   // Create processor with red color for SVG icons
    ///   let processor = OpenHABImageProcessor(iconColor: "red")
    ///
    ///   // Create processor with hex color
    ///   let processor2 = OpenHABImageProcessor(iconColor: "#FF5733")
    ///
    ///   // Create processor without color modification
    ///   let processor3 = OpenHABImageProcessor()
    ///   ```
    public init(iconColor: String? = nil, svgMaxSize: CGSize? = CGSize(width: 64, height: 64)) {
        self.iconColor = iconColor
        self.svgMaxSize = svgMaxSize
        let sizeIdentifier = Self.makeSizeIdentifier(svgMaxSize)
        if let color = iconColor, !color.isEmpty {
            // Normalize the color to hex format for consistent cache identifiers.
            // This ensures that equivalent colors (e.g., "red", "#FF0000", "#ff0000")
            // share the same cache entry rather than creating separate cached images.
            let trimmedLowercased = color.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            var normalizedColor = UIColor(fromString: color).semanticColorToHex() ?? trimmedLowercased
            // Strip the leading '#' from the normalized color for the cache identifier
            if normalizedColor.hasPrefix("#") {
                normalizedColor = String(normalizedColor.dropFirst())
            }
            // If the color was invalid and converted to gray, use the original string instead
            // Gray is 808080, but only fallback if the input wasn't actually meant to be gray
            if normalizedColor.uppercased() == "808080", trimmedLowercased != "gray", !trimmedLowercased.contains("808080") {
                normalizedColor = trimmedLowercased
            }
            identifier = "org.openhab.svgprocessor.\(normalizedColor)\(sizeIdentifier)"
        } else {
            identifier = "org.openhab.svgprocessor\(sizeIdentifier)"
        }
    }

    private static func makeSizeIdentifier(_ size: CGSize?) -> String {
        guard let size else {
            return ".fullsize"
        }
        guard size != defaultSVGMaxSize else {
            return ""
        }
        return ".\(Int(size.width.rounded()))x\(Int(size.height.rounded()))"
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

    /// Applies color styling to SVG image data using the configured `iconColor`.
    ///
    /// This method attempts to parse the provided data as a UTF-8 encoded SVG string
    /// and injects a `style` attribute into the root `<svg>` element so that the
    /// specified color is exposed via the `color` property and used as a default
    /// `fill` color. This allows SVGs that rely on `currentColor` or lack an
    /// explicit `fill` attribute to adopt the desired icon color.
    ///
    /// The method handles three scenarios when modifying the SVG:
    /// 1. **No existing style attribute**: Adds a new `style` attribute with color and fill properties
    /// 2. **Existing style attribute with double quotes**: Prepends color/fill to existing styles
    /// 3. **Existing style attribute with single quotes**: Prepends color/fill to existing styles
    ///
    /// The regex-based approach supports style attributes with optional whitespace around the equals sign
    /// (e.g., `style="..."`, `style='...'`, `style = "..."`, `style  =  '...'`).
    ///
    /// - Parameter data: The raw image data, expected to contain an SVG document
    ///   encoded as UTF-8.
    ///
    /// - Returns: The modified SVG data with color styling applied when possible.
    ///   If `iconColor` is `nil` or empty, if the data cannot be decoded as a
    ///   UTF-8 string, or if the configured color cannot be converted to a hex
    ///   representation, this method returns the original `data` unchanged.
    ///
    /// The method fails gracefully and does not throw; on any parsing or color
    /// conversion issue the input data is passed through without modification.
    func preprocessSVG(_ data: Data) -> Data {
        guard let iconColor, !iconColor.isEmpty,
              let svgString = String(data: data, encoding: .utf8) else {
            return data
        }

        // Convert iconColor to hex format
        let uiColor = UIColor(fromString: iconColor)
        guard let colorString = uiColor.semanticColorToHex() else {
            return data
        }
        Logger.openHABImageProcessor.debug("Preprocessing SVG with color: \(colorString)")

        // Preprocess SVG to apply color
        var processedSVG = svgString

        // Add a style to the SVG root to set color using modern Swift regex
        // Setting 'color' makes it available to 'currentColor' references
        // Setting 'fill' applies to elements without explicit fill attributes
        let svgTagRegex = /<svg[^>]*>/
        if let match = processedSVG.firstMatch(of: svgTagRegex) {
            let svgTag = String(processedSVG[match.range])

            // Check if the svg tag already has a style attribute
            if svgTag.contains("style=") {
                // Prepend to existing style, supporting both single- and double-quoted values
                let styleAttrRegex = /style\s*=\s*(["'])(.*?)\1/
                if let styleMatch = svgTag.firstMatch(of: styleAttrRegex) {
                    let quote = styleMatch.1
                    let existingStyle = String(styleMatch.2)
                    let prefix = "color:\(colorString);fill:\(colorString);"
                    let newStyleContent = prefix + existingStyle
                    let replacement = "style=\(quote)\(newStyleContent)\(quote)"
                    var modifiedTag = svgTag
                    modifiedTag.replaceSubrange(styleMatch.range, with: replacement)
                    processedSVG.replaceSubrange(match.range, with: modifiedTag)
                } else {
                    // Fallback for unexpected formats: preserve previous double-quote behavior
                    let modifiedTag = svgTag.replacingOccurrences(
                        of: "style=\"",
                        with: "style=\"color:\(colorString);fill:\(colorString);",
                        options: .literal
                    )
                    processedSVG.replaceSubrange(match.range, with: modifiedTag)
                }
            } else {
                // Add new style attribute before the closing >
                let modifiedTag = svgTag.replacingOccurrences(
                    of: ">",
                    with: " style=\"color:\(colorString);fill:\(colorString)\">",
                    options: .backwards
                )
                processedSVG.replaceSubrange(match.range, with: modifiedTag)
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

    func process(data: Data) -> UIImage? {
        process(item: .data(data), options: KingfisherParsedOptionsInfo(KingfisherManager.shared.defaultOptions))
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
                // `/icon/none` may legitimately return an empty SVG document.
                // Render this as "no icon" instead of showing the warning fallback.
                if isEmptySVGDocument(data: data) {
                    return UIImage()
                }
                #if os(macOS)
                if let image = renderSVGWithWebKit(data) {
                    return image
                }
                #endif

                // Apply color preprocessing to SVG if iconColor is specified
                let processedData = preprocessSVG(data)

                // Limit decode size for icon contexts; allow full-size decoding for media contexts.
                if let image = decodeSVGOnMain(processedData, targetSize: svgMaxSize, preserveAspectRatio: true) {
                    return image
                }
                return warningSymbol()
            }
            return Kingfisher.DefaultImageProcessor().process(item: item, options: KingfisherParsedOptionsInfo(KingfisherManager.shared.defaultOptions))
        }
    }

    #if os(macOS)
    private func renderSVGWithWebKit(_ data: Data) -> NSImage? {
        guard let svgString = String(data: data, encoding: .utf8) else { return nil }
        let webView = WKWebView(frame: CGRect(origin: .zero, size: CGSize(width: 256, height: 256)))
        webView.loadHTMLString("<html><body style='margin:0'>\(svgString)</body></html>", baseURL: nil)

        let config = WKSnapshotConfiguration()
        config.rect = CGRect(origin: .zero, size: webView.bounds.size)

        var snapshotImage: NSImage?
        let sema = DispatchSemaphore(value: 0)
        webView.takeSnapshot(with: config) { image, _ in
            snapshotImage = image
            sema.signal()
        }
        _ = sema.wait(timeout: .now() + 2)
        return snapshotImage
    }
    #endif

    private func isSVG(data: Data?) -> Bool {
        guard let data else { return false }
        if let start = String(data: data.prefix(200), encoding: .utf8) {
            return start.contains("<svg") || start.hasPrefix("<?xml")
        }
        return false
    }

    func isEmptySVGDocument(data: Data) -> Bool {
        guard let svgString = String(data: data, encoding: .utf8) else { return false }
        let trimmed = svgString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Self-closing root SVG with no children, optionally prefixed with XML declaration.
        if trimmed.wholeMatch(of: /(?:<\?xml[^>]*>\s*)?<svg\b[^>]*\/>\s*/) != nil {
            return true
        }

        // Paired root SVG with only whitespace between open/close tags.
        if trimmed.wholeMatch(of: /(?:<\?xml[^>]*>\s*)?<svg\b[^>]*>\s*<\/svg>\s*/) != nil {
            return true
        }

        return false
    }
}

extension CGSize: @retroactive CustomStringConvertible {
    public var description: String {
        "(\(width), \(height))"
    }
}
