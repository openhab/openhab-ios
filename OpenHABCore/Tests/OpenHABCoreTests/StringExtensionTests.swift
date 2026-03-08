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

import Testing

struct StringExtensionTests {
    @Test func testRemoveTrailingSlashes() throws {
        #expect("example/".removeTrailingSlashes() == "example")
        #expect("example//".removeTrailingSlashes() == "example")
        #expect("example/path//".removeTrailingSlashes() == "example/path")
        #expect("example/path/".removeTrailingSlashes() == "example/path")
        #expect("example/path".removeTrailingSlashes() == "example/path")
        #expect("/".removeTrailingSlashes() == "")
        #expect("///".removeTrailingSlashes() == "")
        #expect("".removeTrailingSlashes() == "")
    }

    @Test
    func testIsNoneIcon() throws {
        let testCases: [String: Bool] = [
            "none": true,
            "oh:none": true,
            "oh:classic:none": true,
            "oh:foo:none": true,
            "f7:none": false,
            "lights": false
        ]

        for (input, expected) in testCases {
            #expect(input.isNoneIcon == expected, "\(input) failed")
        }
    }

    @Test
    func testDataImageBase64Payload() throws {
        let svgPayload = "PHN2Zz48L3N2Zz4="
        #expect("data:image/svg+xml;base64,\(svgPayload)".dataImageBase64Payload == svgPayload)

        let pngPayload = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB"
        #expect("data:image/png;base64,\(pngPayload)".dataImageBase64Payload == pngPayload)

        #expect("data:image/svg+xml;base64".dataImageBase64Payload == nil)
        #expect("http://example.com/image.png".dataImageBase64Payload == nil)
        #expect("".dataImageBase64Payload == nil)
    }
}
