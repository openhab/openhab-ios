//
//  OpenHABHTTPRequestOperation.swift
//  openHAB
//
//  Created by David O'Neill on 03/09/19.
//  Copyright (c) 2019 David O'Neill. All rights reserved.

import Foundation

var trustedCertificates: [AnyHashable: Any] = [:]

private struct Certificates {

    static func getPersistensePath() -> String? {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        let filePath = URL(fileURLWithPath: documentsDirectory).appendingPathComponent("trustedCertificates").absoluteString
        return filePath
    }

    static func loadTrustedCertificates() {
        if let unarchive = NSKeyedUnarchiver.unarchiveObject(withFile: self.getPersistensePath() ?? "") as? [AnyHashable: Any] {
            trustedCertificates = unarchive
        }
    }

    static func storeCertificateData(_ certificate: CFData?, forDomain domain: String?) {
        let certificateData = certificate as Data?
        trustedCertificates[domain] = certificateData
        self.saveTrustedCertificates()
    }

    static func saveTrustedCertificates() {
        NSKeyedArchiver.archiveRootObject(trustedCertificates, toFile: self.getPersistensePath() ?? "")
    }

}
