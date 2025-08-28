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

@testable import OpenHABCore
import XCTest

final class OpenHABImageProcessorTests: XCTestCase {
    var processor: OpenHABImageProcessor!
    
    override func setUp() {
        super.setUp()
        processor = OpenHABImageProcessor()
    }
    
    override func tearDown() {
        processor = nil
        super.tearDown()
    }
    
    // Test the SVG detection logic
    func testSVGDetection_ValidSVG() {
        let validSVG = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <circle cx="50" cy="50" r="40" fill="red"/>
        </svg>
        """
        let data = Data(validSVG.utf8)
        
        // Use the internal isSVG method
        let isSVGResult = processor.isSVG(data: data)
        XCTAssertTrue(isSVGResult, "Valid SVG should be detected")
    }
    
    func testSVGDetection_XMLWithSVG() {
        let xmlSVG = """
        <?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg">
            <rect width="100" height="100"/>
        </svg>
        """
        let data = Data(xmlSVG.utf8)
        
        let isSVGResult = processor.isSVG(data: data)
        XCTAssertTrue(isSVGResult, "XML with SVG should be detected")
    }
    
    func testSVGDetection_NonSVG() {
        let nonSVG = "This is just regular text content"
        let data = Data(nonSVG.utf8)
        
        let isSVGResult = processor.isSVG(data: data)
        XCTAssertFalse(isSVGResult, "Non-SVG content should not be detected as SVG")
    }
    
    func testSVGDetection_EmptyData() {
        let emptyData = Data()
        
        let isSVGResult = processor.isSVG(data: emptyData)
        XCTAssertFalse(isSVGResult, "Empty data should not be detected as SVG")
    }
    
    func testSVGDetection_BinaryData() {
        let binaryData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG header
        
        let isSVGResult = processor.isSVG(data: binaryData)
        XCTAssertFalse(isSVGResult, "Binary data should not be detected as SVG")
    }
    
    // Test validation for size limits and safety checks
    func testSVGValidation_TooLarge() {
        // Create a large SVG string (over 10MB)
        let largeSVGContent = String(repeating: "<!-- padding -->", count: 700000) // ~11MB
        let largeSVG = "<svg>\(largeSVGContent)</svg>"
        let data = Data(largeSVG.utf8)
        
        let isValid = processor.isValidSVGData(data)
        XCTAssertFalse(isValid, "Oversized SVG should be rejected")
    }
    
    func testSVGValidation_InvalidUTF8() {
        // Create invalid UTF-8 data with SVG-like beginning
        var invalidData = Data("<svg>".utf8)
        invalidData.append(contentsOf: [0xFF, 0xFE, 0xFD]) // Invalid UTF-8 bytes
        
        let isValid = processor.isValidSVGData(invalidData)
        XCTAssertFalse(isValid, "Invalid UTF-8 SVG should be rejected")
    }
    
    func testSVGValidation_MissingSVGElement() {
        let xmlWithoutSVG = """
        <?xml version="1.0"?>
        <root>
            <rect width="100" height="100"/>
        </root>
        """
        let data = Data(xmlWithoutSVG.utf8)
        
        let isValid = processor.isValidSVGData(data)
        XCTAssertFalse(isValid, "XML without SVG element should be rejected")
    }
    
    func testSVGValidation_JavaScriptPattern() {
        let maliciousSVG = """
        <svg xmlns="http://www.w3.org/2000/svg">
            <image href="javascript:alert('xss')"/>
        </svg>
        """
        let data = Data(maliciousSVG.utf8)
        
        let isValid = processor.isValidSVGData(data)
        XCTAssertFalse(isValid, "SVG with javascript should be rejected")
    }
    
    func testSVGValidation_ForeignObjectPattern() {
        let problematicSVG = """
        <svg xmlns="http://www.w3.org/2000/svg">
            <foreignObject width="100" height="100">
                <div>Potentially problematic content</div>
            </foreignObject>
        </svg>
        """
        let data = Data(problematicSVG.utf8)
        
        let isValid = processor.isValidSVGData(data)
        XCTAssertFalse(isValid, "SVG with foreignObject should be rejected")
    }
    
    func testSVGValidation_ValidSVG() {
        let validSVG = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <circle cx="50" cy="50" r="40" fill="red"/>
            <rect x="10" y="10" width="30" height="30" fill="blue"/>
        </svg>
        """
        let data = Data(validSVG.utf8)
        
        let isValid = processor.isValidSVGData(data)
        XCTAssertTrue(isValid, "Valid SVG should pass validation")
    }
    
    func testSVGValidation_ProblematicStructure() {
        let problematicSVG = """
        <svg xmlns="http://www.w3.org/2000/svg">
            <defs>
                <pattern id="p1" width="1000" height="1000">
                    <rect width="1000" height="1000"/>
                </pattern>
            </defs>
            <rect width="4000" height="4000" fill="url(#p1)"/>
        </svg>
        """
        let data = Data(problematicSVG.utf8)
        
        let isValid = processor.isValidSVGData(data)
        XCTAssertFalse(isValid, "SVG with problematic structure should be rejected")
    }
}
}