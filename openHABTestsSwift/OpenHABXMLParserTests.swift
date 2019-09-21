//
//  OpenHABNewXMLParserTests.swift
//  Pods-openHABTestsSwift
//
//  Created by Tim Müller-Seydlitz on 19.08.19.
//

import Fuzi
import XCTest

enum TestingError: Error {
    case noXMLDocument
}

class OpenHABXMLParserTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testFuziParser() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.

        let xml = """
<item>
        <type>NumberItem</type>
        <name>Office_Temperature</name>
        <state>21.20</state>
        <link>http://192.168.0.249:8080/rest/items/Office_Temperature</link>
    </item>
""".data(using: .utf8)!

        do {
            let document = try XMLDocument(data: xml)
            if let root = document.root {
                let item = OpenHABItem(xml: root)
                XCTAssertEqual(item.type, "NumberItem")
            } else {
                throw TestingError.noXMLDocument
            }
        } catch {
            XCTFail("Not able to parse XML Sitemap")
        }
    }

    func testFuzisingleXMLWidgetDecoder() {
        var widget: OpenHABWidget

        do {
            let document = try XMLDocument(data: singleWidgetXML!)
            if let root = document.root {
                widget = OpenHABWidget(xml: root)
                XCTAssertEqual(widget.item?.name, "Lights")
            } else {
                throw TestingError.noXMLDocument
            }
        } catch {
            XCTFail("Not able to parse single XML widget")
        }
    }

    func testnestedXMLWidgetDecoder() {
        var widget: OpenHABWidget

        do {
            let document = try XMLDocument(data: nestedWidgetXML!)
            if let root = document.root {
                widget = OpenHABWidget(xml: root)
                XCTAssertEqual(widget.widgets[0].item?.state, "OFF")
            } else {
                throw TestingError.noXMLDocument
            }
        } catch {
            XCTFail("Not able to parse nested XML widget")
        }
    }

    func testshortUrlXMLWidgetDecoder() {
        var widget: OpenHABWidget

        do {
            let document = try XMLDocument(data: shorturlwidgetXML!)
            if let root = document.root {
                widget = OpenHABWidget(xml: root)
                XCTAssertEqual(widget.url, "http://openhab:8080/proxy?sitemap=default.sitemap")
            } else {
                throw TestingError.noXMLDocument
            }
        } catch {
            XCTFail("Not able to parse short XML widget with url")
        }
    }

    func testUrlXMLWidgetDecoder() {
        var widget: OpenHABWidget

        do {
            let document = try XMLDocument(data: urlwidgetXML!)
            if let root = document.root {
                widget = OpenHABWidget(xml: root)
                XCTAssertEqual(widget.url, "http://openhab:8080/proxy?sitemap=default.sitemap&widgetId=01000001")
            } else {
                throw TestingError.noXMLDocument
            }
        } catch {
            XCTFail("Not able to parse XML widget with url")
        }
    }

    func testXMLPageDecoder() {
        var sitemapPage: OpenHABSitemapPage
        do {
            let document = try XMLDocument(data: homepageXML!)
            if let root = document.root {
                sitemapPage = OpenHABSitemapPage(xml: root)
                XCTAssertEqual(sitemapPage.widgets[0].widgets[0].item?.state, "OFF", "XML sitemap properly parsed")
            } else {
                throw TestingError.noXMLDocument
            }
        } catch {
            XCTFail("Not able to parse XML sitemap page")
        }
    }

    func testXMLFullParse() {
        var currentPage: OpenHABSitemapPage
        do {
            let document = try XMLDocument(data: fullxml!)
            if let rootElement = document.root, rootElement.tag == "sitemap" {
                for child in rootElement.children where child.tag == "homepage" {
                    currentPage = OpenHABSitemapPage(xml: child)
                    XCTAssertEqual(currentPage.widgets[0].widgets[0].item?.state, "OFF", "Full XML sitemap page properly parsed")
                }
            } else {
                throw TestingError.noXMLDocument
            }
        } catch {
            XCTFail("Not able to parse full XML sitemap page ")
        }
    }

    func testXMLFullSitemapParse() {
        var currentPage: OpenHABSitemapPage
        do {
            let document = try XMLDocument(data: fullsitemapXML!)
            if let rootElement = document.root, rootElement.tag == "page" {
                currentPage = OpenHABSitemapPage(xml: rootElement)
                XCTAssertEqual(currentPage.widgets[0].widgets[0].item?.state, "OFF", "Full XML sitemap page properly parsed")
            } else {
                throw TestingError.noXMLDocument
            }
        } catch {
            XCTFail("Not able to parse full XML sitemap page ")
        }
    }

    func testXMLFullSitemapPageParse() {
        var sitemaps = [OpenHABSitemap]()

        do {
            let document = try XMLDocument(data: userprovidedXML!)
            if let rootElement = document.root, rootElement.tag == "sitemaps" {
                for element in rootElement.children(tag: "sitemap") {
                    let sitemap = OpenHABSitemap(xml: element)
                    sitemaps.append(sitemap)
                }
                XCTAssertEqual(sitemaps[0].homepageLink, "http://localhost:8080/rest/sitemaps/devices/devices", "Full XML sitemap list properly parsed")
            } else {
                throw TestingError.noXMLDocument
            }
        } catch {
            XCTFail("Not able to parse full XML sitemap page ")
        }
    }
}
