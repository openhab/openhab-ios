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
        // Add validation to prevent processing of potentially problematic SVG data
        guard isValidSVGData(data) else {
            logger.warning("SVG data failed validation checks, skipping decode")
            return nil
        }
        
        return mainSync {
            // Create an autoreleasepool to manage memory during SVG processing
            autoreleasepool {
                // Add additional safety by limiting the decoding options
                let options: [SDImageCoderOption: Any] = [
                    .decodeScaleFactor: 1.0,
                    .decodePreserveAspectRatio: true
                ]
                
                let result = SDImageSVGCoder.shared.decodedImage(
                    with: data,
                    options: options
                )
                
                // Validate the result before returning
                if let image = result {
                    let size = image.size
                    // Additional safety check for reasonable image dimensions
                    if size.width <= 0 || size.height <= 0 || size.width > 4096 || size.height > 4096 {
                        logger.warning("SVG decoded to invalid or excessive dimensions: \(size.width)x\(size.height)")
                        return nil
                    }
                }
                
                return result
            }
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

    internal func isSVG(data: Data?) -> Bool {
        guard let data else { return false }
        if let start = String(data: data.prefix(200), encoding: .utf8) {
            return start.contains("<svg") || start.hasPrefix("<?xml")
        }
        return false
    }
    
    /// Validate SVG data to prevent processing of potentially problematic content
    internal func isValidSVGData(_ data: Data) -> Bool {
        // Basic size check - reject extremely large SVGs
        guard data.count < 10_000_000 else { // 10MB limit
            logger.warning("SVG data too large: \(data.count) bytes")
            return false
        }
        
        // Check for valid UTF-8 encoding in the first portion
        guard let svgString = String(data: data.prefix(min(data.count, 8192)), encoding: .utf8) else {
            logger.warning("SVG data contains invalid UTF-8 encoding")
            return false
        }
        
        // Basic XML structure validation
        let lowercased = svgString.lowercased()
        guard lowercased.contains("<svg") else {
            logger.warning("SVG data missing required <svg> element")
            return false
        }
        
        // Check for potentially problematic patterns that could cause crashes
        let problematicPatterns = [
            "javascript:",
            "data:image/svg+xml;base64",  // Nested SVGs can cause issues
            "<script",
            "xlink:href=\"data:",
            "<foreignobject"  // Can contain arbitrary HTML
        ]
        
        for pattern in problematicPatterns {
            if lowercased.contains(pattern) {
                logger.warning("SVG contains potentially problematic pattern: \(pattern)")
                return false
            }
        }
        
        // Additional checks for potentially problematic structures
        if isProblematicSVGStructure(svgString, logger: logger) {
            return false
        }
        
        return true
    }
    
    /// Check for problematic SVG structures that could cause crashes or performance issues
    private func isProblematicSVGStructure(_ svgString: String, logger: Logger) -> Bool {
        let lowercased = svgString.lowercased()
        
        // Check for excessive use of pattern elements (can cause memory issues)
        let patternCount = lowercased.components(separatedBy: "<pattern").count - 1
        if patternCount > 10 {
            logger.warning("SVG contains excessive number of patterns: \(patternCount)")
            return true
        }
        
        // Check for very large pattern dimensions that could cause memory issues
        if lowercased.contains("pattern") && 
           (lowercased.contains("width=\"10000") || lowercased.contains("height=\"10000") ||
            lowercased.contains("width=\"1000") || lowercased.contains("height=\"1000")) {
            logger.warning("SVG contains pattern with large dimensions")
            return true
        }
        
        // Check for excessive number of gradient definitions
        let gradientCount = (lowercased.components(separatedBy: "gradient").count - 1)
        if gradientCount > 50 {
            logger.warning("SVG contains excessive number of gradients: \(gradientCount)")
            return true
        }
        
        // Check for very large rectangle dimensions that could cause rendering issues
        if lowercased.contains("rect") &&
           (lowercased.contains("width=\"4000") || lowercased.contains("height=\"4000") ||
            lowercased.contains("width=\"5000") || lowercased.contains("height=\"5000")) {
            logger.warning("SVG contains rect with very large dimensions")
            return true
        }
        
        return false
    }
}
