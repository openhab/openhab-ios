//
//  OpenHABFormatTests.swift
//  openHABTestsSwift
//
//  Created by Tim Müller-Seydlitz on 09.08.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import XCTest

class OpenHABFormatTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    func testValueToText() {
        func valueText(_ widgetValue: Double, step: Double) -> String {
            let digits = max (-Decimal(step).exponent, 0)
            let numberFormatter = NumberFormatter()
            numberFormatter.minimumFractionDigits = digits
            numberFormatter.decimalSeparator  = "."
            return numberFormatter.string(from: NSNumber(value: widgetValue)) ?? ""
        }

        func valueTextWithoutFormatter(_ widgetValue: Double, step: Double) -> String {
            let digits = max (-Decimal(step).exponent, 0)
            return String(format: "%.\(digits)f", widgetValue)
        }

        XCTAssertEqual(valueText(1000.0, step: 5.23), "1000.00")
        XCTAssertEqual(valueText(1000.0, step: 1), "1000")
        XCTAssertEqual(valueTextWithoutFormatter(1000.0, step: 5.23), "1000.00")

    }

    func testXMLSitemapDecoder() {
        let json = """
<sitemaps><sitemap>
    <name>default</name>
    <label>Welcome Home</label>
    <link>http://192.168.170.5:8080/rest/sitemaps/default</link>
    <homepage><link>http://192.168.170.5:8080/rest/sitemaps/default/default</link>
    <leaf>false</leaf></homepage>
    </sitemap></sitemaps>
""".data(using: .utf8)!

        var sitemaps = [OpenHABSitemap]()

        if let doc: GDataXMLDocument? = try? GDataXMLDocument(data: json) {
            if doc?.rootElement().name() == "sitemaps" {
                for element in doc?.rootElement().elements(forName: "sitemap") ?? [] {
                    if let element = element as? GDataXMLElement {
                        let sitemap = OpenHABSitemap(xml: element)
                        sitemaps.append(sitemap)
                    }
                }
            }
        }
        XCTAssert(sitemaps[0].homepageLink == "http://192.168.170.5:8080/rest/sitemaps/default/default", "JSON Sitemap properly parsed")

    }

    func testXMLSitemapPageDecoder() {
        let json = """
<sitemap>
    <name>default</name>
    <label>Križ 62a</label>
    <link>http://192.168.0.249:8080/rest/sitemaps/default</link>
    <homepage>
        <id>default</id>
        <title>Križ 62a</title>
        <link>http://192.168..249:8080/rest/sitemaps/default/default</link>
    <leaf>false</leaf>
    <widget>
    <widgetId>default_0</widgetId>
    <type>Frame</type>
    <label/>
    <icon>frame</icon>
    <widget>
        <widgetId>default_0_0</widgetId>
        <type>Text</type>
        <label>Nadstropje [21.2 °C]</label>
    <icon>attic</icon>
    <valuecolor>#008000</valuecolor>
    <item>
        <type>NumberItem</type>
        <name>Office_Temperature</name>
        <state>21.20</state>
        <link>http://192.168.0.249:8080/rest/items/Office_Temperature</link>
    </item>
""".data(using: .utf8)!

        var sitemaps = [OpenHABSitemap]()

        if let doc: GDataXMLDocument? = try? GDataXMLDocument(data: json) {
            if doc?.rootElement().name() == "sitemaps" {
                for element in doc?.rootElement().elements(forName: "sitemap") ?? [] {
                    if let element = element as? GDataXMLElement {
                        let sitemap = OpenHABSitemap(xml: element)
                        sitemaps.append(sitemap)
                    }
                }
            }
        }
        XCTAssert(sitemaps[0].homepageLink == "http://192.168.170.5:8080/rest/sitemaps/default/default", "JSON Sitemap properly parsed")
<<<<<<< HEAD

    }
=======
    }

>>>>>>> 2f62e0e... Typos
}
