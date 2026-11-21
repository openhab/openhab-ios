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

@testable import openHAB
import OpenHABCore
import Testing

struct OpenHABGeneralTests {
    @Test func namedColors() {
        #expect(UIColor.red == UIColor(fromString: "red"))
        #expect(UIColor.gray == UIColor(fromString: "abc"))
    }

    @Test func valueToText() {
        func valueTextWithoutFormatter(_ widgetValue: Double, step: Double) -> String {
            let digits = max(-Decimal(step).exponent, 0)
            return String(format: "%.\(digits)f", widgetValue)
        }

        let value = 1000.0
        #expect(value.valueText(step: 0.01) == "1000.00")
        #expect(value.valueText(step: 1) == "1000")
        #expect(valueTextWithoutFormatter(1000.0, step: 5.23) == "1000.00")
    }

    @Test func hexString() {
        let iPhoneData = Data("Tim iPhone".utf8)
        let hexWithReduce = iPhoneData.reduce("") { $0 + String(format: "%02X", $1) }
        #expect(hexWithReduce == "54696D206950686F6E65")
    }

    @Test func webViewURLParsing() {
        let localURL = "http://openhab.local:8080"

        let httpURL = "http://camera.example.com/stream"
        let httpResult = httpURL.lowercased().hasPrefix("http://") || httpURL.lowercased().hasPrefix("https://") ? httpURL : localURL + httpURL
        #expect(httpResult == httpURL)

        let httpsURL = "https://camera.example.com/stream"
        let httpsResult = httpsURL.lowercased().hasPrefix("http://") || httpsURL.lowercased().hasPrefix("https://") ? httpsURL : localURL + httpsURL
        #expect(httpsResult == httpsURL)

        let relativeURL = "/proxy/camera"
        let relativeResult = relativeURL.lowercased().hasPrefix("http://") || relativeURL.lowercased().hasPrefix("https://") ? relativeURL : localURL + relativeURL
        #expect(relativeResult == localURL + relativeURL)

        let uppercaseHttpsURL = "HTTPS://example.com/image.jpg"
        let uppercaseResult = uppercaseHttpsURL.lowercased().hasPrefix("http://") || uppercaseHttpsURL.lowercased().hasPrefix("https://") ? uppercaseHttpsURL : localURL + uppercaseHttpsURL
        #expect(uppercaseResult == uppercaseHttpsURL)
    }
}
