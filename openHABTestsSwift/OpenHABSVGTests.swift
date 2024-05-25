// Copyright (c) 2010-2024 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import SVGKit
import XCTest

class OpenHABSVGTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /// Invalid SVG
    func testInvalidXMLNS() throws {
        let svgTestFile = "invalid_xmlns"
        // xmlns is defined by referring to DTD ENTITY.

        do {
            let url = Bundle(for: Self.self).url(forResource: svgTestFile, withExtension: "svg")
            let data = try Data(contentsOf: url!)
            let svgkSourceNSData = SVGKSourceNSData.source(from: data, urlForRelativeLinks: nil)
            let parseResults = SVGKParser.parseSource(usingDefaultSVGKParser: svgkSourceNSData)
            XCTAssertEqual(parseResults?.parsedDocument, nil, "parsedDocument not empty though it was expected to be because XML is invalid")
            XCTAssertEqual(parseResults?.errorsFatal.count ?? 0, 0, "No errorsFatal expected")
            XCTAssertEqual((parseResults?.warnings[0] as! NSError).localizedDescription, "xmlns: URI &ns_svg; is not absolute\n")
        } catch {
            XCTFail("Whoops, an unexpected error occured while unit testing SVG rendering")
        }
    }

    func testUseTagPoints2NonExistentElement() throws {
        let svgTestFile = "pantryUseTagPoints2NonExistentElement"

        do {
            let url = Bundle(for: Self.self).url(forResource: svgTestFile, withExtension: "svg")
            let data = try Data(contentsOf: url!)
            let svgkSourceNSData = SVGKSourceNSData.source(from: data, urlForRelativeLinks: nil)
            let parseResults = SVGKParser.parseSource(usingDefaultSVGKParser: svgkSourceNSData)
            XCTAssertNotEqual(parseResults?.parsedDocument, nil, "Non nil parsedDocument expected")
            XCTAssertNotEqual(parseResults?.errorsFatal.count, 0, "errorsFatal are 0")
            let fatalError = parseResults?.errorsFatal[0] as! NSError
            XCTAssertEqual(fatalError.localizedDescription, "Exception = Found an SVG <use> tag that points to a non-existent element. Missing element: id = e")
        } catch {
            XCTFail("Whoops, an unexpected error occured while unit testing SVG rendering")
        }
    }

    /// Valid SVG
    ///

    func testValidEmbeddedPNG() throws {
        let svgTestFile = "embeddedpng_valid"

        do {
            let url = Bundle(for: Self.self).url(forResource: svgTestFile, withExtension: "svg")
            let data = try Data(contentsOf: url!)
            let svgkSourceNSData = SVGKSourceNSData.source(from: data, urlForRelativeLinks: nil)
            let parseResults = SVGKParser.parseSource(usingDefaultSVGKParser: svgkSourceNSData)
            let image = SVGKImage(parsedSVG: parseResults, from: svgkSourceNSData)
            XCTAssertNotEqual(parseResults?.parsedDocument, nil, "Non nil parsedDocument expected")
            XCTAssertEqual(parseResults?.errorsFatal.count, 0, "No errorsFatal expected")
            XCTAssertNotEqual(image, nil, "Conversion to image not feasible")
        } catch {
            XCTFail("Whoops, an unexpected error occured while unit testing SVG rendering")
        }
    }

    func testValidXMLNS() throws {
        let svgTestFile = "valid_xmlns"

        do {
            let url = Bundle(for: Self.self).url(forResource: svgTestFile, withExtension: "svg")
            let data = try Data(contentsOf: url!)
            let svgkSourceNSData = SVGKSourceNSData.source(from: data, urlForRelativeLinks: nil)
            let parseResults = SVGKParser.parseSource(usingDefaultSVGKParser: svgkSourceNSData)
            let image = SVGKImage(parsedSVG: parseResults, from: svgkSourceNSData)
            XCTAssertNotEqual(parseResults?.parsedDocument, nil, "Non nil parsedDocument expected")
            XCTAssertEqual(parseResults?.errorsFatal.count, 0, "No errorsFatal expected")
            XCTAssertNotEqual(image, nil, "Conversion to image not feasible")
        } catch {
            XCTFail("Whoops, an unexpected error occured while unit testing SVG rendering")
        }
    }
}
