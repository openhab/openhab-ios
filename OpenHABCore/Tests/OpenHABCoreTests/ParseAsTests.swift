// Copyright (c) 2010-2026 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

@testable import OpenHABCore

import XCTest

final class ParseAsTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.

        XCTAssertFalse("10,10,0".parseAsBool())
        XCTAssertTrue("10,10,50".parseAsBool())
    }

    func testValidOpenHABURL() throws {
        try "http://localhost:8080".testAsValidOpenHABURL()
        try "https://localhost:8080".testAsValidOpenHABURL()
        try "192.168.2.10".testAsValidOpenHABURL()
    }

    func testInvalidOpenHABURL() {
        let invalidURLs = [
            "ftp://localhost", // Unsupported scheme
            "http:/localhost", // Malformed
            "http://", // Missing host
            "://localhost", // Missing scheme
            "file:///Users/me", // Unsupported scheme
            "https://" // No host
        ]

        for url in invalidURLs {
            XCTAssertThrowsError(try url.testAsValidOpenHABURL(), "Expected to throw for URL: \(url)") { error in
                if let urlError = error as? URLError {
                    XCTAssertEqual(urlError.code, .badURL, "Expected .badURL, got \(urlError.code)")
                } else {
                    XCTFail("Unexpected error type: \(error)")
                }
            }
        }
    }
}
