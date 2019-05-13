//
//  ImageDownloadUtil.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 12.05.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation
import SDWebImage

var imageOptionsIgnoreInvalidCertIfDefined: SDWebImageOptions {
    let prefs = UserDefaults.standard
    let ignoreSSLCertificate = prefs.bool(forKey: "ignoreSSL")

    // See https://developer.apple.com/documentation/swift/optionset
    var options = SDWebImageOptions()
    if ignoreSSLCertificate {
        options.insert(.allowInvalidSSLCertificates)
    }
    return options
}
