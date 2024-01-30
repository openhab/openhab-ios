// Copyright (c) 2010-2024 Contributors to the openHAB project
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
import UIKit

// See https://github.com/SDWebImage/SDWebImageSVGCoder/blob/master/SDWebImageSVGCoder/Classes/SDImageSVGCoder.m
// and transposition into Swift in https://gist.github.com/ollieatkinson/eb87a82fcb5500d5561fed8b0900a9f7

@objc
class CGSVGDocument: NSObject {}

var cgSVGDocumentRetain: (@convention(c) (CGSVGDocument?) -> Unmanaged<CGSVGDocument>?) = load("CGSVGDocumentRetain")
var cgSVGDocumentRelease: (@convention(c) (CGSVGDocument?) -> Void) = load("CGSVGDocumentRelease")
var cgSVGDocumentCreateFromData: (@convention(c) (CFData?, CFDictionary?) -> Unmanaged<CGSVGDocument>?) = load("CGSVGDocumentCreateFromData")
var cgContextDrawSVGDocument: (@convention(c) (CGContext?, CGSVGDocument?) -> Void) = load("CGContextDrawSVGDocument")
var cgSVGDocumentGetCanvasSize: (@convention(c) (CGSVGDocument?) -> CGSize) = load("CGSVGDocumentGetCanvasSize")

typealias ImageWithCGSVGDocument = @convention(c) (AnyObject, Selector, CGSVGDocument) -> UIImage
var imageWithCGSVGDocumentSEL: Selector = NSSelectorFromString("_imageWithCGSVGDocument:")

let coreSVG = dlopen("/System/Library/PrivateFrameworks/CoreSVG.framework/CoreSVG", RTLD_NOW)

func load<T>(_ name: String) -> T {
    unsafeBitCast(dlsym(coreSVG, name), to: T.self)
}

public final class SVG {
    let document: CGSVGDocument

    public var size: CGSize {
        cgSVGDocumentGetCanvasSize(document)
    }

    public convenience init?(_ value: String) {
        guard let data = value.data(using: .utf8) else { return nil }
        self.init(data)
    }

    public init?(_ data: Data) {
        guard let document = cgSVGDocumentCreateFromData(data as CFData, nil)?.takeUnretainedValue() else { return nil }
        guard cgSVGDocumentGetCanvasSize(document) != .zero else { return nil }
        self.document = document
    }

    public func image() -> UIImage? {
        let imageWithCGSVGDocument = unsafeBitCast(UIImage.method(for: imageWithCGSVGDocumentSEL), to: ImageWithCGSVGDocument.self)
        let image = imageWithCGSVGDocument(UIImage.self, imageWithCGSVGDocumentSEL, document)
        return image
    }

    public func draw(in context: CGContext) {
        draw(in: context, size: size)
    }

    public func draw(in context: CGContext, size target: CGSize) {
        var target = target

        let ratio = (
            x: target.width / size.width,
            y: target.height / size.height
        )

        let rect = (
            document: CGRect(origin: .zero, size: size), ()
        )

        let scale: (x: CGFloat, y: CGFloat)

        if target.width <= 0 {
            scale = (ratio.y, ratio.y)
            target.width = size.width * scale.x
        } else if target.height <= 0 {
            scale = (ratio.x, ratio.x)
            target.width = size.width * scale.y
        } else {
            let min = min(ratio.x, ratio.y)
            scale = (min, min)
            target.width = size.width * scale.x
            target.height = size.height * scale.y
        }

        let transform = (
            scale: CGAffineTransform(scaleX: scale.x, y: scale.y),
            aspect: CGAffineTransform(translationX: (target.width / scale.x - rect.document.width) / 2, y: (target.height / scale.y - rect.document.height) / 2)
        )

        context.translateBy(x: 0, y: target.height)
        context.scaleBy(x: 1, y: -1)
        context.concatenate(transform.scale)
        context.concatenate(transform.aspect)

        cgContextDrawSVGDocument(context, document)
    }

}

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
                // recognized by header of data
                // <?xml version="1.0" encoding="UTF-8"?>
                // <svg

                guard let svg = SVG(data) else { return UIImage(named: "error.png") }

                if #available(watchOS 5, *) { // os(watchOS)
                    let size = svg.size
                    UIGraphicsBeginImageContext(size)
                    guard let context = UIGraphicsGetCurrentContext() else { return nil }
                    svg.draw(in: context)

                    // Convert to UIImage
                    let cgimage = context.makeImage()
                    let uiimage = UIImage(cgImage: cgimage!)

                    // End the graphics context
                    UIGraphicsEndImageContext()
                    return uiimage
                } else {
                    return svg.image()
                }

            default:
                return Kingfisher.DefaultImageProcessor().process(item: item, options: KingfisherParsedOptionsInfo(KingfisherManager.shared.defaultOptions))
            }
        }
    }
}
