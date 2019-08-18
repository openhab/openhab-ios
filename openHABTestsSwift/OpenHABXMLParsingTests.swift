//
//  OpenHABXMLParsingTests.swift
//  openHABTestsSwift
//
//  Created by Tim Müller-Seydlitz on 18.08.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

//import SwiftyXMLParser
import XCTest

class OpenHABXMLParsingTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.

        let str = """
<ResultSet>
    <Result>
        <Hit index=\"1\">
            <Name>Item1</Name>
        </Hit>
        <Hit index=\"2\">
            <Name>Item2</Name>
        </Hit>
    </Result>
</ResultSet>
"""

        // parse xml document
//        let xmldocument = XMLDocument(data: singleWidgetXML)
//
//            let xmlparser = XMLParser(data: singleWidgetXML)

    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
