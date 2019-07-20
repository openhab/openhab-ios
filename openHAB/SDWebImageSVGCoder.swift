//
//  SDWebImageSVGCoder.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 19.07.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation
import SDWebImage
import SVGKit

class MySDWebImageSVGCoder: NSObject, SDImageCoder {

    static let shared = MySDWebImageSVGCoder()

    var data: Data?

    func canDecode(from data: Data?) -> Bool {
        guard let data = data else { return false }
        guard data.count > 100 else { return false }
        guard let testString = String(data: data.subdata(in: (data.count-100)..<data.count), encoding: .ascii) else { return false }
        guard testString.contains("</svg>") else { return false }
        return true
    }

    func decodedImage(with data: Data?, options: [SDImageCoderOption: Any]? = nil) -> UIImage? {
        guard let data = data else { return nil }
        let receivedIcon: SVGKImage = SVGKImage(data: data)
        return receivedIcon.uiImage
    }

    func decompressedImage(with image: Data?, options: [SDImageCoderOption: Any]? = nil) -> UIImage? {
        guard let data = data else { return nil }
        let receivedIcon: SVGKImage = SVGKImage(data: data)
        return receivedIcon.uiImage
    }

    func canEncode(to format: SDImageFormat) -> Bool {
        return false
    }

    func encodedData(with image: UIImage?, format: SDImageFormat, options: [SDImageCoderOption: Any]? = nil) -> Data? {
        return nil
    }

}
