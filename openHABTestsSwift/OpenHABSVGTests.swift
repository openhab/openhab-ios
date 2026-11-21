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
import Testing
import UIKit

private final class OpenHABSVGTestsBundleToken {}

struct OpenHABSVGTests {
    private func renderSVG(named name: String) throws -> UIImage? {
        let bundle = Bundle(for: OpenHABSVGTestsBundleToken.self)
        guard let url = bundle.url(forResource: name, withExtension: "svg") else {
            throw NSError(
                domain: "TestError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "SVG file \(name).svg not found in test bundle"]
            )
        }
        let data = try Data(contentsOf: url)
        return OpenHABImageProcessor().process(data: data)
    }

    /// The app-level contract is graceful SVG handling via OpenHABImageProcessor.
    /// Some fixtures are not directly decodable by Apple's built-in SVG renderer,
    /// but the processor must still return a fallback image instead of nil.
    @Test
    func validSVGWithEmbeddedPNG() throws {
        let image = try renderSVG(named: "embeddedpng_valid")
        #expect(image != nil)
    }

    @Test
    func validSVGWithXMLNS() throws {
        let image = try renderSVG(named: "valid_xmlns")
        #expect(image != nil)
    }

    @Test
    func invalidXMLNS() throws {
        let image = try renderSVG(named: "invalid_xmlns")
        #expect(image != nil)
    }

    @Test
    func useTagPointsToNonExistentElement() throws {
        let image = try renderSVG(named: "pantryUseTagPoints2NonExistentElement")
        #expect(image != nil)
    }
}
