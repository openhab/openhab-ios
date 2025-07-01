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

@testable import openHAB
import XCTest

class OpenHABGeneralTests: XCTestCase {
    func testNamedColors() {
        XCTAssertEqual(UIColor.red, UIColor(fromString: "red"))
        XCTAssertEqual(UIColor.gray, UIColor(fromString: "abc"))
    }

    func testValueToText() {
        func valueTextWithoutFormatter(_ widgetValue: Double, step: Double) -> String {
            let digits = max(-Decimal(step).exponent, 0)
            return String(format: "%.\(digits)f", widgetValue)
        }

        XCTAssertEqual(1000.0.valueText(step: 0.01), "1000.00")
        XCTAssertEqual(1000.0.valueText(step: 1), "1000")
        XCTAssertEqual(valueTextWithoutFormatter(1000.0, step: 5.23), "1000.00")
    }

    func testHexString() {
        let iPhoneData: Data = "Tim iPhone".data(using: .utf8)!
        let hexWithReduce = iPhoneData.reduce("") { $0 + String(format: "%02X", $1) }
        XCTAssertEqual(hexWithReduce, "54696D206950686F6E65", "hex properly calculated with reduce")
    }

    func testWebViewURLParsing() {
        let localURL = "http://openhab.local:8080"

        // Test external HTTP URL
        let httpURL = "http://camera.example.com/stream"
        let httpResult = httpURL.lowercased().hasPrefix("http://") || httpURL.lowercased().hasPrefix("https://") ? httpURL : localURL + httpURL
        XCTAssertEqual(httpResult, httpURL, "External HTTP URL should not be modified")

        // Test external HTTPS URL
        let httpsURL = "https://camera.example.com/stream"
        let httpsResult = httpsURL.lowercased().hasPrefix("http://") || httpsURL.lowercased().hasPrefix("https://") ? httpsURL : localURL + httpsURL
        XCTAssertEqual(httpsResult, httpsURL, "External HTTPS URL should not be modified")

        // Test relative URL
        let relativeURL = "/proxy/camera"
        let relativeResult = relativeURL.lowercased().hasPrefix("http://") || relativeURL.lowercased().hasPrefix("https://") ? relativeURL : localURL + relativeURL
        XCTAssertEqual(relativeResult, localURL + relativeURL, "Relative URL should be combined with local URL")

        // Test case-insensitive HTTPS
        let uppercaseHttpsURL = "HTTPS://example.com/image.jpg"
        let uppercaseResult = uppercaseHttpsURL.lowercased().hasPrefix("http://") || uppercaseHttpsURL.lowercased().hasPrefix("https://") ? uppercaseHttpsURL : localURL + uppercaseHttpsURL
        XCTAssertEqual(uppercaseResult, uppercaseHttpsURL, "Uppercase HTTPS URL should not be modified")
    }
}
