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
        let xml = """
<sitemaps><sitemap>
    <name>default</name>
    <label>Welcome Home</label>
    <link>http://192.168.170.5:8080/rest/sitemaps/default</link>
    <homepage><link>http://192.168.170.5:8080/rest/sitemaps/default/default</link>
    <leaf>false</leaf></homepage>
    </sitemap></sitemaps>
""".data(using: .utf8)!

        var sitemaps = [OpenHABSitemap]()

        if let doc: GDataXMLDocument? = try? GDataXMLDocument(data: xml) {
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

    func testXMLItemDecoder() {
        let xml = """
<item>
        <type>NumberItem</type>
        <name>Office_Temperature</name>
        <state>21.20</state>
        <link>http://192.168.0.249:8080/rest/items/Office_Temperature</link>
    </item>
""".data(using: .utf8)!

        var item: OpenHABItem

        if let doc: GDataXMLDocument? = try? GDataXMLDocument(data: xml), let rootElement = doc?.rootElement() {
            item = OpenHABItem(xml: rootElement)
            XCTAssert(item.name == "Office_Temperature", "XML Sitemap properly parsed")
        } else {
            XCTFail("Not able to parse XML Sitemap")
        }
    }

    func testsingleXMLWidgetDecoder() {
        var widget: OpenHABWidget

        if let doc: GDataXMLDocument? = try? GDataXMLDocument(data: singleWidgetXML), let rootElement = doc?.rootElement() {
                widget = OpenHABWidget(xml: rootElement)
                XCTAssert(widget.item?.name == "Lights", "Single XML Widget properly parsed")
        } else {
            XCTFail("Not able to parse single XML widget")
        }
    }

    func testnestedXMLWidgetDecoder() {
        var widget: OpenHABWidget

        if let doc: GDataXMLDocument? = try? GDataXMLDocument(data: nestedWidgetXML), let rootElement = doc?.rootElement() {
                widget = OpenHABWidget(xml: rootElement)
                XCTAssert(widget.widgets[0].item?.state == "OFF", "Nested XML Widget properly parsed")
        } else {
            XCTFail("Not able to parse nested XML widget")
        }
    }

    func testXMLPageDecoder() {
        var sitemapPage: OpenHABSitemapPage

        if let doc: GDataXMLDocument? = try? GDataXMLDocument(data: homepageXML), let rootElement = doc?.rootElement() {
            sitemapPage = OpenHABSitemapPage(xml: rootElement)
            XCTAssert(sitemapPage.widgets[0].widgets[0].item?.state == "OFF", "XML sitemap properly parsed")
        } else {
            XCTFail("Not able to parse XML sitemap page")
        }
    }

    func testXMLFullParse() {
        var currentPage: OpenHABSitemapPage

        guard let doc = try? GDataXMLDocument(data: fullxml) else { return }

        if doc.rootElement().name() == "sitemap", let rootElement = doc.rootElement() {
            for child in rootElement.children() {
                if let child = child as? GDataXMLElement, child.name() == "homepage" {
                    currentPage = OpenHABSitemapPage(xml: child)
                    XCTAssert(currentPage.widgets[0].widgets[0].item?.state == "OFF", "Full XML sitemap page properly parsed")
                }
            }
        } else {
            XCTFail("Not able to parse full XML sitemap page ")
        }
    }

    func testXMLFullSitemapParse() {
        var currentPage: OpenHABSitemapPage

        guard let doc = try? GDataXMLDocument(data: fullsitemapXML) else { return }

        if doc.rootElement().name() == "page", let rootElement = doc.rootElement() {

            currentPage = OpenHABSitemapPage(xml: rootElement)
            XCTAssert(currentPage.widgets[0].widgets[0].item?.state == "OFF", "Full XML sitemap page properly parsed")

        } else {
            XCTFail("Not able to parse full XML sitemap page ")
        }
    }

}
