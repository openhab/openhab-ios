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

import SDWebImageSVGCoder
import XCTest

class OpenHABSVGTests: XCTestCase {
    // SDImageSVGCoder is registered by AppDelegate before any tests run.

    func decodeSVG(named name: String) throws -> UIImage? {
        guard let url = Bundle(for: Self.self).url(forResource: name, withExtension: "svg") else {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "SVG file not found"])
        }
        let data = try Data(contentsOf: url)
        return SDImageSVGCoder.shared.decodedImage(with: data, options: nil)
    }

    // ✅ Valid SVG test
    func testValidSVGWithEmbeddedPNG() throws {
        let image = try decodeSVG(named: "embeddedpng_valid")
        XCTAssertNotNil(image, "Expected image to be decoded successfully")
    }

    func testValidSVGWithXMLNS() throws {
        let image = try decodeSVG(named: "valid_xmlns")
        XCTAssertNotNil(image, "Expected image to be decoded successfully")
    }

    // ❌ Invalid SVGs for SVGKit. They are working for SDWebImageSVGCoder
    func testInvalidXMLNS() throws {
        let image = try decodeSVG(named: "invalid_xmlns")
        XCTAssertNotNil(image, "Expected image to be decoded successfully")
    }

    func testUseTagPoints2NonExistentElement() throws {
        let image = try decodeSVG(named: "pantryUseTagPoints2NonExistentElement")
        XCTAssertNotNil(image, "Expected image to be decoded successfully")
    }
}
