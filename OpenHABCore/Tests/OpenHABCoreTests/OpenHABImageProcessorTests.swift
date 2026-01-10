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

import Foundation
@testable import OpenHABCore
import Testing

struct OpenHABImageProcessorTests {
    // MARK: - Test preprocessSVG

    @Test func preprocessSVG_withCurrentColor() async throws {
        // SVG with currentColor fill attribute
        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 16 16"><path fill="currentColor" d="M10 2.29v2.124c.566.247 1.086.6 1.536 1.05C12.48 6.408 13 7.664 13 9s-.52 2.591-1.464 3.536S9.336 14 8 14s-2.591-.52-3.536-1.464S3 10.336 3 9s.52-2.591 1.464-3.536c.45-.45.97-.803 1.536-1.05V2.29a7 7 0 1 0 4 0M7 0h2v8H7z"/></svg>
        """
        let svgData = svgString.data(using: .utf8)!

        // Process with red color
        let processor = OpenHABImageProcessor(iconColor: "red")
        let processedData = processor.preprocessSVG(svgData)
        let processedString = String(data: processedData, encoding: .utf8)!

        // Verify that style attribute was added with both color and fill
        // 'color' is needed for currentColor references, 'fill' for elements without explicit fill
        #expect(processedString.contains("style=\"color:#"))
        #expect(processedString.contains("fill:#"))
        #expect(processedString.contains("<svg"))
        #expect(processedString.contains("</svg>"))
        #expect(processedString.contains("fill=\"currentColor\""), "Original currentColor attribute should be preserved")
    }

    @Test func preprocessSVG_withoutIconColor() async throws {
        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><circle cx="32" cy="32" r="30" fill="blue"/></svg>
        """
        let svgData = svgString.data(using: .utf8)!

        // Process without icon color
        let processor = OpenHABImageProcessor(iconColor: nil)
        let processedData = processor.preprocessSVG(svgData)
        let processedString = String(data: processedData, encoding: .utf8)!

        // Verify that SVG is unchanged
        #expect(processedString == svgString)
    }

    @Test func preprocessSVG_withEmptyIconColor() async throws {
        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect x="0" y="0" width="64" height="64" fill="green"/></svg>
        """
        let svgData = svgString.data(using: .utf8)!

        // Process with empty icon color
        let processor = OpenHABImageProcessor(iconColor: "")
        let processedData = processor.preprocessSVG(svgData)
        let processedString = String(data: processedData, encoding: .utf8)!

        // Verify that SVG is unchanged
        #expect(processedString == svgString)
    }

    @Test func preprocessSVG_withExistingStyleAttribute() async throws {
        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" style="stroke:black;"><circle cx="32" cy="32" r="30"/></svg>
        """
        let svgData = svgString.data(using: .utf8)!

        // Process with blue color
        let processor = OpenHABImageProcessor(iconColor: "blue")
        let processedData = processor.preprocessSVG(svgData)
        let processedString = String(data: processedData, encoding: .utf8)!

        // Verify that color and fill were prepended to existing style
        #expect(processedString.contains("style=\"color:#"))
        #expect(processedString.contains("fill:#"))
        #expect(processedString.contains("stroke:black;"))
    }

    @Test func preprocessSVG_withHexColor() async throws {
        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><path d="M0 0h32v32H0z"/></svg>
        """
        let svgData = svgString.data(using: .utf8)!

        // Process with hex color
        let processor = OpenHABImageProcessor(iconColor: "#FF5733")
        let processedData = processor.preprocessSVG(svgData)
        let processedString = String(data: processedData, encoding: .utf8)!

        // Verify that style attribute was added
        #expect(processedString.contains("style=\"color:#"))
        #expect(processedString.contains("fill:#"))
    }

    @Test func preprocessSVG_withRGBColor() async throws {
        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><circle cx="50" cy="50" r="40"/></svg>
        """
        let svgData = svgString.data(using: .utf8)!

        // Process with RGB color
        let processor = OpenHABImageProcessor(iconColor: "rgb(255, 0, 0)")
        let processedData = processor.preprocessSVG(svgData)
        let processedString = String(data: processedData, encoding: .utf8)!

        // Verify that style attribute was added
        #expect(processedString.contains("style=\"color:#"))
        #expect(processedString.contains("fill:#"))
    }

    @Test func preprocessSVG_preservesOtherAttributes() async throws {
        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 16 16" class="icon" data-test="value"><path d="M0 0h16v16H0z"/></svg>
        """
        let svgData = svgString.data(using: .utf8)!

        // Process with color
        let processor = OpenHABImageProcessor(iconColor: "orange")
        let processedData = processor.preprocessSVG(svgData)
        let processedString = String(data: processedData, encoding: .utf8)!

        // Verify that other attributes are preserved
        #expect(processedString.contains("width=\"64\""))
        #expect(processedString.contains("height=\"64\""))
        #expect(processedString.contains("viewBox=\"0 0 16 16\""))
        #expect(processedString.contains("class=\"icon\""))
        #expect(processedString.contains("data-test=\"value\""))
        #expect(processedString.contains("style=\"color:#"))
        #expect(processedString.contains("fill:#"))
    }

    @Test func preprocessSVG_withInvalidData() async throws {
        let invalidData = "Not an SVG".data(using: .utf8)!

        // Process with color
        let processor = OpenHABImageProcessor(iconColor: "red")
        let processedData = processor.preprocessSVG(invalidData)

        // Verify that invalid data is returned unchanged
        #expect(processedData == invalidData)
    }

    @Test func preprocessSVG_withMultilineSVG() async throws {
        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg"
             width="64"
             height="64"
             viewBox="0 0 16 16">
            <path d="M0 0h16v16H0z"/>
        </svg>
        """
        let svgData = svgString.data(using: .utf8)!

        // Process with color
        let processor = OpenHABImageProcessor(iconColor: "purple")
        let processedData = processor.preprocessSVG(svgData)
        let processedString = String(data: processedData, encoding: .utf8)!

        // Verify that style attribute was added
        #expect(processedString.contains("style=\"color:#"))
        #expect(processedString.contains("fill:#"))
    }

    @Test func preprocessSVG_verifyColorValue() async throws {
        // Verify that the exact hex color value is correctly inserted
        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><circle cx="16" cy="16" r="15" fill="currentColor"/></svg>
        """
        let svgData = svgString.data(using: .utf8)!

        let processor = OpenHABImageProcessor(iconColor: "red")
        let processedData = processor.preprocessSVG(svgData)
        let processedString = String(data: processedData, encoding: .utf8)!

        // Red should convert to #FF0000
        #expect(processedString.contains("color:#FF0000"))
        #expect(processedString.contains("fill:#FF0000"))
    }
}
