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

import SDWebImageSVGCoder
import XCTest
@testable import OpenHABCore

class OpenHABSVGTests: XCTestCase {
    override func setUpWithError() throws {
        SDImageCodersManager.shared.addCoder(SDImageSVGCoder.shared)
    }

    override func tearDownWithError() throws {
        // Optional: Remove coder if needed
    }

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
    
    // Test the new OpenHABImageProcessor with existing SVG files
    func testOpenHABImageProcessorWithValidSVGs() throws {
        let processor = OpenHABImageProcessor()
        
        // Test with each existing SVG file
        let svgNames = ["embeddedpng_valid", "valid_xmlns", "invalid_xmlns", "pantryUseTagPoints2NonExistentElement"]
        
        for svgName in svgNames {
            guard let url = Bundle(for: Self.self).url(forResource: svgName, withExtension: "svg") else {
                XCTFail("Could not find SVG file: \(svgName)")
                continue
            }
            
            let data = try Data(contentsOf: url)
            let result = processor.process(item: .data(data), options: .init([]))
            
            // Should either return a valid image or a warning symbol, but never crash or return nil
            XCTAssertNotNil(result, "OpenHABImageProcessor should handle \(svgName) without crashing")
        }
    }
    
    func testOpenHABImageProcessorWithProblematicSVG() throws {
        let processor = OpenHABImageProcessor()
        
        // Test with a potentially problematic SVG (the one from the crash report style)
        let problematicSVG = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
            <defs>
                <!-- Pattern that could cause memory issues -->
                <pattern id="p1" width="1000" height="1000" patternUnits="userSpaceOnUse">
                    <rect width="1000" height="1000" fill="red"/>
                </pattern>
                <!-- Large gradients that could cause issues -->
                <radialGradient id="g1">
                    <stop offset="0%" stop-color="red"/>
                    <stop offset="100%" stop-color="blue"/>
                </radialGradient>
            </defs>
            <!-- Large rect that could cause rendering issues -->
            <rect width="4000" height="4000" fill="url(#p1)"/>
        </svg>
        """
        
        let data = Data(problematicSVG.utf8)
        let result = processor.process(item: .data(data), options: .init([]))
        
        // Should return warning symbol for problematic SVG, not crash
        XCTAssertNotNil(result, "OpenHABImageProcessor should handle problematic SVG safely")
        
        // Since this is problematic, it should return the warning symbol
        // (We can't test the exact image but we can verify it doesn't crash)
    }
    
    func testOpenHABImageProcessorValidation() throws {
        let processor = OpenHABImageProcessor()
        
        // Test validation of existing SVG files
        let svgNames = ["embeddedpng_valid", "valid_xmlns", "invalid_xmlns", "pantryUseTagPoints2NonExistentElement"]
        
        for svgName in svgNames {
            guard let url = Bundle(for: Self.self).url(forResource: svgName, withExtension: "svg") else {
                XCTFail("Could not find SVG file: \(svgName)")
                continue
            }
            
            let data = try Data(contentsOf: url)
            
            // All existing test SVGs should be detected as SVG
            XCTAssertTrue(processor.isSVG(data: data), "\(svgName) should be detected as SVG")
            
            // All existing test SVGs should pass validation (they are legitimate test files)
            XCTAssertTrue(processor.isValidSVGData(data), "\(svgName) should pass validation")
        }
    }
}
