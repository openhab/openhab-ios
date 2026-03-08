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
import Kingfisher
@testable import OpenHABCore
import Testing

struct OpenHABImageProcessorTests {
    // MARK: - Test preprocessSVG

    @Test func preprocessSVG_withCurrentColor() throws {
        // SVG with currentColor fill attribute
        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 16 16"><path fill="currentColor" d="M10 2.29v2.124c.566.247 1.086.6 1.536 1.05C12.48 6.408 13 7.664 13 9s-.52 2.591-1.464 3.536S9.336 14 8 14s-2.591-.52-3.536-1.464S3 10.336 3 9s.52-2.591 1.464-3.536c.45-.45.97-.803 1.536-1.05V2.29a7 7 0 1 0 4 0M7 0h2v8H7z"/></svg>
        """
        let svgData = Data(svgString.utf8)

        // Process with red color
        let processor = OpenHABImageProcessor(iconColor: "red")
        let processedData = processor.preprocessSVG(svgData)
        let processedString = String(bytes: processedData, encoding: .utf8)!

        // Verify that style attribute was added with both color and fill
        // 'color' is needed for currentColor references, 'fill' for elements without explicit fill
        #expect(processedString.contains("style=\"color:#"))
        #expect(processedString.contains("fill:#"))
        #expect(processedString.contains("<svg"))
        #expect(processedString.contains("</svg>"))
        #expect(processedString.contains("fill=\"currentColor\""), "Original currentColor attribute should be preserved")
    }

    @Test func preprocessSVG_withoutIconColor() throws {
        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><circle cx="32" cy="32" r="30" fill="blue"/></svg>
        """
        let svgData = Data(svgString.utf8)

        // Process without icon color
        let processor = OpenHABImageProcessor(iconColor: nil)
        let processedData = processor.preprocessSVG(svgData)
        let processedString = String(bytes: processedData, encoding: .utf8)!

        // Verify that SVG is unchanged
        #expect(processedString == svgString)
    }

    @Test func preprocessSVG_withEmptyIconColor() throws {
        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect x="0" y="0" width="64" height="64" fill="green"/></svg>
        """
        let svgData = Data(svgString.utf8)

        // Process with empty icon color
        let processor = OpenHABImageProcessor(iconColor: "")
        let processedData = processor.preprocessSVG(svgData)
        let processedString = String(bytes: processedData, encoding: .utf8)!

        // Verify that SVG is unchanged
        #expect(processedString == svgString)
    }

    @Test func preprocessSVG_withExistingStyleAttribute() throws {
        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" style="stroke:black;"><circle cx="32" cy="32" r="30"/></svg>
        """
        let svgData = Data(svgString.utf8)

        // Process with blue color
        let processor = OpenHABImageProcessor(iconColor: "blue")
        let processedData = processor.preprocessSVG(svgData)
        let processedString = String(bytes: processedData, encoding: .utf8)!

        // Verify that color and fill were prepended to existing style
        #expect(processedString.contains("style=\"color:#"))
        #expect(processedString.contains("fill:#"))
        #expect(processedString.contains("stroke:black;"))
    }

    @Test func preprocessSVG_withSingleQuotedStyleAttribute() throws {
        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" style='stroke:black;'><circle cx="32" cy="32" r="30"/></svg>
        """
        let svgData = Data(svgString.utf8)

        // Process with green color
        let processor = OpenHABImageProcessor(iconColor: "green")
        let processedData = processor.preprocessSVG(svgData)
        let processedString = String(bytes: processedData, encoding: .utf8)!

        // Verify that color and fill were prepended to existing style with single quotes preserved
        #expect(processedString.contains("style='color:#"))
        #expect(processedString.contains("fill:#"))
        #expect(processedString.contains("stroke:black;"))
        #expect(processedString.contains("#008000")) // Green hex color
    }

    @Test func preprocessSVG_withStyleAttributeAndWhitespace() throws {
        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" style = "opacity:0.8;"><rect x="0" y="0" width="64" height="64"/></svg>
        """
        let svgData = Data(svgString.utf8)

        // Process with orange color
        let processor = OpenHABImageProcessor(iconColor: "orange")
        let processedData = processor.preprocessSVG(svgData)
        let processedString = String(bytes: processedData, encoding: .utf8)!

        // Verify that style with whitespace is handled correctly
        #expect(processedString.contains("color:#"))
        #expect(processedString.contains("fill:#"))
        #expect(processedString.contains("opacity:0.8;"))
    }

    @Test func preprocessSVG_withSingleQuotedStyleAndWhitespace() throws {
        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" style  =  'margin:10px;'><path d="M0 0h32v32H0z"/></svg>
        """
        let svgData = Data(svgString.utf8)

        // Process with purple color
        let processor = OpenHABImageProcessor(iconColor: "purple")
        let processedData = processor.preprocessSVG(svgData)
        let processedString = String(bytes: processedData, encoding: .utf8)!

        // Verify that single-quoted style with whitespace is handled correctly
        #expect(processedString.contains("color:#"))
        #expect(processedString.contains("fill:#"))
        #expect(processedString.contains("margin:10px;"))
        #expect(processedString.contains("style") && processedString.contains("'"))
    }

    @Test func preprocessSVG_withHexColor() throws {
        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><path d="M0 0h32v32H0z"/></svg>
        """
        let svgData = Data(svgString.utf8)

        // Process with hex color
        let processor = OpenHABImageProcessor(iconColor: "#FF5733")
        let processedData = processor.preprocessSVG(svgData)
        let processedString = String(bytes: processedData, encoding: .utf8)!

        // Verify that style attribute was added
        #expect(processedString.contains("style=\"color:#"))
        #expect(processedString.contains("fill:#"))
    }

    @Test func preprocessSVG_withRGBColor() throws {
        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><circle cx="50" cy="50" r="40"/></svg>
        """
        let svgData = Data(svgString.utf8)

        // Process with RGB color
        let processor = OpenHABImageProcessor(iconColor: "rgb(255, 0, 0)")
        let processedData = processor.preprocessSVG(svgData)
        let processedString = String(bytes: processedData, encoding: .utf8)!

        // Verify that style attribute was added
        #expect(processedString.contains("style=\"color:#"))
        #expect(processedString.contains("fill:#"))
    }

    @Test func preprocessSVG_preservesOtherAttributes() throws {
        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 16 16" class="icon" data-test="value"><path d="M0 0h16v16H0z"/></svg>
        """
        let svgData = Data(svgString.utf8)

        // Process with color
        let processor = OpenHABImageProcessor(iconColor: "orange")
        let processedData = processor.preprocessSVG(svgData)
        let processedString = String(bytes: processedData, encoding: .utf8)!

        // Verify that other attributes are preserved
        #expect(processedString.contains("width=\"64\""))
        #expect(processedString.contains("height=\"64\""))
        #expect(processedString.contains("viewBox=\"0 0 16 16\""))
        #expect(processedString.contains("class=\"icon\""))
        #expect(processedString.contains("data-test=\"value\""))
        #expect(processedString.contains("style=\"color:#"))
        #expect(processedString.contains("fill:#"))
    }

    @Test func preprocessSVG_withInvalidData() throws {
        let invalidData = Data("Not an SVG".utf8)

        // Process with color
        let processor = OpenHABImageProcessor(iconColor: "red")
        let processedData = processor.preprocessSVG(invalidData)

        // Verify that invalid data is returned unchanged
        #expect(processedData == invalidData)
    }

    @Test func preprocessSVG_withMultilineSVG() throws {
        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg"
             width="64"
             height="64"
             viewBox="0 0 16 16">
            <path d="M0 0h16v16H0z"/>
        </svg>
        """
        let svgData = Data(svgString.utf8)

        // Process with color
        let processor = OpenHABImageProcessor(iconColor: "purple")
        let processedData = processor.preprocessSVG(svgData)
        let processedString = String(bytes: processedData, encoding: .utf8)!

        // Verify that style attribute was added
        #expect(processedString.contains("style=\"color:#"))
        #expect(processedString.contains("fill:#"))
    }

    @Test func emptySVG_selfClosingRoot_isDetectedAsEmpty() throws {
        let svgString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg viewBox="0 0 1 1" xmlns="http://www.w3.org/2000/svg"/>
        """
        let svgData = Data(svgString.utf8)
        let processor = OpenHABImageProcessor()

        #expect(processor.isEmptySVGDocument(data: svgData))
    }

    @Test func emptySVG_withOpenAndCloseTag_isDetectedAsEmpty() throws {
        let svgString = """
        <svg viewBox="0 0 1 1" xmlns="http://www.w3.org/2000/svg"></svg>
        """
        let svgData = Data(svgString.utf8)
        let processor = OpenHABImageProcessor()

        #expect(processor.isEmptySVGDocument(data: svgData))
    }

    @Test func nonEmptySVG_isNotDetectedAsEmpty() throws {
        let svgString = """
        <svg viewBox="0 0 1 1" xmlns="http://www.w3.org/2000/svg"><path d="M0 0h1v1H0z"/></svg>
        """
        let svgData = Data(svgString.utf8)
        let processor = OpenHABImageProcessor()

        #expect(!processor.isEmptySVGDocument(data: svgData))
    }

    @Test func process_emptySVG_returnsEmptyImageNotWarningSymbol() throws {
        let svgString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg viewBox="0 0 1 1" xmlns="http://www.w3.org/2000/svg"/>
        """
        let svgData = Data(svgString.utf8)
        let processor = OpenHABImageProcessor(iconColor: "red")
        let options = KingfisherParsedOptionsInfo(KingfisherManager.shared.defaultOptions)

        let image = processor.process(item: .data(svgData), options: options)

        #expect(image != nil)
        #expect(image?.size == .zero)
    }

    @Test func preprocessSVG_verifyColorValue() throws {
        // Verify that the exact hex color value is correctly inserted
        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><circle cx="16" cy="16" r="15" fill="currentColor"/></svg>
        """
        let svgData = Data(svgString.utf8)

        let processor = OpenHABImageProcessor(iconColor: "red")
        let processedData = processor.preprocessSVG(svgData)
        let processedString = String(bytes: processedData, encoding: .utf8)!

        // Red should convert to #FF0000
        #expect(processedString.contains("color:#FF0000"))
        #expect(processedString.contains("fill:#FF0000"))
    }

    // MARK: - Cache Identifier Normalization Tests

    @Test func cacheIdentifier_normalizesNamedColors() throws {
        // Verify that named colors are normalized to hex for consistent cache identifiers
        let processor1 = OpenHABImageProcessor(iconColor: "red")
        let processor2 = OpenHABImageProcessor(iconColor: "#FF0000")
        let processor3 = OpenHABImageProcessor(iconColor: "#ff0000")
        let processor4 = OpenHABImageProcessor(iconColor: "FF0000")

        // All variations of red should produce the same cache identifier
        #expect(processor1.identifier == processor2.identifier)
        #expect(processor2.identifier == processor3.identifier)
        #expect(processor3.identifier == processor4.identifier)
        #expect(processor1.identifier == "org.openhab.svgprocessor.FF0000")
    }

    @Test func cacheIdentifier_handlesDifferentColors() throws {
        // Verify that different colors produce different cache identifiers
        let redProcessor = OpenHABImageProcessor(iconColor: "red")
        let blueProcessor = OpenHABImageProcessor(iconColor: "blue")
        let greenProcessor = OpenHABImageProcessor(iconColor: "green")

        #expect(redProcessor.identifier != blueProcessor.identifier)
        #expect(blueProcessor.identifier != greenProcessor.identifier)
        #expect(redProcessor.identifier != greenProcessor.identifier)
    }

    @Test func cacheIdentifier_withoutColor() throws {
        // Verify that processors without color have the default identifier
        let processor1 = OpenHABImageProcessor()
        let processor2 = OpenHABImageProcessor(iconColor: nil)
        let processor3 = OpenHABImageProcessor(iconColor: "")

        #expect(processor1.identifier == "org.openhab.svgprocessor")
        #expect(processor2.identifier == "org.openhab.svgprocessor")
        #expect(processor3.identifier == "org.openhab.svgprocessor")
    }

    @Test func cacheIdentifier_fullSizeMode() throws {
        let processorWithoutColor = OpenHABImageProcessor(svgMaxSize: nil)
        let processorWithColor = OpenHABImageProcessor(iconColor: "red", svgMaxSize: nil)

        #expect(processorWithoutColor.identifier == "org.openhab.svgprocessor.fullsize")
        #expect(processorWithColor.identifier == "org.openhab.svgprocessor.FF0000.fullsize")
    }

    @Test func cacheIdentifier_customSizeMode() throws {
        let processor = OpenHABImageProcessor(iconColor: "red", svgMaxSize: CGSize(width: 128, height: 128))

        #expect(processor.identifier == "org.openhab.svgprocessor.FF0000.128x128")
    }

    @Test func cacheIdentifier_normalizesOpenHABColors() throws {
        // Verify that openHAB semantic colors are normalized
        let processor1 = OpenHABImageProcessor(iconColor: "maroon")
        let processor2 = OpenHABImageProcessor(iconColor: "#800000")

        #expect(processor1.identifier == processor2.identifier)
        #expect(processor1.identifier == "org.openhab.svgprocessor.800000")
    }

    @Test func cacheIdentifier_handlesWhitespace() throws {
        // Verify that whitespace is handled correctly
        let processor1 = OpenHABImageProcessor(iconColor: "  red  ")
        let processor2 = OpenHABImageProcessor(iconColor: "red")
        let processor3 = OpenHABImageProcessor(iconColor: "  #FF0000  ")

        #expect(processor1.identifier == processor2.identifier)
        #expect(processor2.identifier == processor3.identifier)
    }

    @Test func cacheIdentifier_handlesCaseSensitivity() throws {
        // Verify that color strings are case-insensitive
        let processor1 = OpenHABImageProcessor(iconColor: "RED")
        let processor2 = OpenHABImageProcessor(iconColor: "Red")
        let processor3 = OpenHABImageProcessor(iconColor: "red")

        #expect(processor1.identifier == processor2.identifier)
        #expect(processor2.identifier == processor3.identifier)
    }

    @Test func cacheIdentifier_fallbackForInvalidColors() throws {
        // Verify that invalid colors fall back to normalized string
        let processor = OpenHABImageProcessor(iconColor: "xyz")

        // Invalid colors should still produce a consistent identifier
        // (falls back to trimmed, lowercased string)
        #expect(processor.identifier.contains("xyz"))
    }
}
