//
//  ImageDownloadUtil.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 12.05.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation
import SDWebImage

extension SDWebImageOptions {

    func insertSSLOptions() -> SDWebImageOptions {
        let prefs = UserDefaults.standard
        let ignoreSSLCertificate = prefs.bool(forKey: "ignoreSSL")

        // See https://developer.apple.com/documentation/swift/optionset
        var options = self
        if ignoreSSLCertificate {
            options.insert(.allowInvalidSSLCertificates)
        }
        return options
    }
    static var imageOptionsIgnoreInvalidCertIfDefined: SDWebImageOptions {
        return SDWebImageOptions().insertSSLOptions()
    }

    static var imageOptionFromLoaderOnlyIgnoreInvalidCert: SDWebImageOptions {
        let options: SDWebImageOptions = .fromLoaderOnly
        return options.insertSSLOptions()
    }
}
