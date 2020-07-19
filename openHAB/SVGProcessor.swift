// Copyright (c) 2010-2020 Contributors to the openHAB project
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
// import Macaw

struct SVGMacawProcessor: ImageProcessor {
    // `identifier` should be the same for processors with the same properties/functionality
    // It will be used when storing and retrieving the image to/from cache.
    let identifier = "svgprocessor"
    var size: CGSize!
    init(size: CGSize) {
        self.size = size
    }

    // Convert input data/image to target image and return it.
    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        switch item {
        case let .image(image):
            return image
        case let .data(data):
//            if let svgString = String(data: data, encoding: .utf8) {
//                UIImageView(i)
//                let node = try! SVGParser.parse(text: svgString)
//
//                let paths = SVGBezierPath.paths(fromSVGString: svgString)
//                let layer = SVGLayer()
//                layer.paths = paths
//                let frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
//                layer.frame = frame
//                let img = snapshotImage(for: layer)
//                return img
//            }
            return nil
        }
    }

    func snapshotImage(for view: CALayer) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        view.render(in: context)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
