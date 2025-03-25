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
import SVGKit

struct OpenHABImageProcessor: ImageProcessor {
    // `identifier` should be the same for processors with the same properties/functionality
    // It will be used when storing and retrieving the image to/from cache.
    let identifier = "org.openhab.svgprocessor"

    // Convert input data/image to target image and return it.
    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
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
                let svgkSourceNSData = SVGKSourceNSData.source(from: data, urlForRelativeLinks: nil)
                let parseResults = SVGKParser.parseSource(usingDefaultSVGKParser: svgkSourceNSData)
                if parseResults?.parsedDocument != nil, let image = SVGKImage(parsedSVG: parseResults, from: svgkSourceNSData), image.hasSize() {
                    if image.size.width > 1000 || image.size.height > 1000 {
                        return UIImage(systemSymbol: .exclamationmarkTriangle).withTintColor(.orange)
                    }
                    return image.uiImage
                } else {
                    return UIImage(systemSymbol: .exclamationmarkTriangle).withTintColor(.orange)
                }
            default:
                return Kingfisher.DefaultImageProcessor().process(item: item, options: KingfisherParsedOptionsInfo(KingfisherManager.shared.defaultOptions))
            }
        }
    }
}
