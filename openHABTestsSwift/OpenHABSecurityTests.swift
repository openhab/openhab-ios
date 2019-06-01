//
//  OpenHABSecurityTests.swift
//  openHABTestsSwift
//
//  Created by Tim Müller-Seydlitz on 15.05.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import XCTest

class OpenHABSecurityTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    private var currentPageOperation: OpenHABHTTPRequestOperation?

    func testAFSecurity() {
        AFRememberingSecurityPolicy.initializeCertificatesStore()

        let pageToLoadUrl = URL(string: "192.168.2.15")
        let pageRequest = URLRequest(url: pageToLoadUrl!)
        currentPageOperation = OpenHABHTTPRequestOperation(request: pageRequest as URLRequest, delegate: self as? AFRememberingSecurityPolicyDelegate)

        let domain: String? = "ts"
        if let previousCertificateData = AFRememberingSecurityPolicy.certificateData(forDomain: domain) {
//            if CFEqual(previousCertificateData, certificateData) {
//                // If certificate matched one in our store - permit this connection
//                return true
//            } else {
//            }
        }
    }

}
