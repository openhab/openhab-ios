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

    // Convert input data/image to target image and return it.
    public func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        switch item {
        case let .image(image):
            logger.info("already an image")
            return image
        case let .data(data):
            guard !data.isEmpty else { return nil }

            switch data[0] {
            case 0x3C: // Likely SVG, since it starts with '<'
                logger.info("Processing as SVG")
                if let image = SDImageSVGCoder.shared.decodedImage(with: data, options: nil) {
                    let size = image.size
                    if size.width > 1000 || size.height > 1000 {
                        return UIImage(systemSymbol: .exclamationmarkTriangle).withTintColor(.orange, renderingMode: .alwaysOriginal)
                    }
                    logger.info("SVG decoded successfully")
                    return image
                } else {
                    logger.error("Failed to decode SVG")
                    return UIImage(systemSymbol: .exclamationmarkTriangle).withTintColor(.orange, renderingMode: .alwaysOriginal)
                }
            default:
                logger.error("Not an SVG image")
                return Kingfisher.DefaultImageProcessor().process(item: item, options: KingfisherParsedOptionsInfo(KingfisherManager.shared.defaultOptions))
            }
        }
    }
}
