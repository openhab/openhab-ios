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

public struct OpenHABImageProcessor: ImageProcessor {
    // `identifier` should be the same for processors with the same properties/functionality
    // It will be used when storing and retrieving the image to/from cache.
    public let identifier = "org.openhab.svgprocessor"

    public init() {}

    // Convert input data/image to target image and return it.
    public func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        switch item {
        case let .image(image):
            os_log("already an image", log: .default, type: .info)
            return image
        case let .data(data):
            guard !data.isEmpty else { return nil }

            switch data[0] {
            case 0x3C: // svg
                // <?xml version="1.0" encoding="UTF-8"?>
                // <svg
                if let image = SDImageSVGCoder.shared.decodedImage(with: data, options: nil) {
                    let size = image.size
                    if size.width > 1000 || size.height > 1000 {
                        return UIImage(systemName: "exclamationmark.triangle")?.withTintColor(.orange, renderingMode: .alwaysOriginal)
                    }
                    return image
                } else {
                    return UIImage(systemName: "exclamationmark.triangle")?.withTintColor(.orange, renderingMode: .alwaysOriginal)
                }
            default:
                return Kingfisher.DefaultImageProcessor().process(item: item, options: KingfisherParsedOptionsInfo(KingfisherManager.shared.defaultOptions))
            }
        }
    }
}
