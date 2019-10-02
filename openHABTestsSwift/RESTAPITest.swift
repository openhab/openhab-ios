//
//  RESTAPITest.swift
//  openHABTestsSwift
//
//  Created by Tim Müller-Seydlitz on 15.09.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

@testable import Alamofire
@testable import openHAB
import XCTest

class RESTAPITest: XCTestCase {
    override func setUp() {
        super.setUp()

        let manager: SessionManager = {
            let configuration: URLSessionConfiguration = {
                let configuration = URLSessionConfiguration.default
                configuration.protocolClasses = [MockURLProtocol.self]
                return configuration
            }()

            return SessionManager(configuration: configuration)
        }()

        class MockURLRequestAdapter: RequestAdapter {
            func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
                return urlRequest
            }
        }

        NetworkConnection.shared = NetworkConnection(ignoreSSL: true,
                                                     manager: manager,
                                                     adapter: MockURLRequestAdapter())
    }

    override func tearDown() {
        super.tearDown()

        NetworkConnection.shared = nil
    }

    func testStatusCode200ReturnsStatusCode200() {
        // given
        MockURLProtocol.responseWithStatusCode(code: 200)

        let expectation = XCTestExpectation(description: "Performs a request")

        // when
        let pageToLoadUrl = URL(string: "http://192.168.2.16")!
        let pageRequest = URLRequest(url: pageToLoadUrl)
        let registrationOperation = NetworkConnection.shared.manager.request(pageRequest)
            .validate(statusCode: 200 ..< 300)
            .responseData { response in
                XCTAssertEqual(response.response?.statusCode, 200)
                expectation.fulfill()
            }
        registrationOperation.resume()

        // then
        wait(for: [expectation], timeout: 3)
    }

    func testRegisterApp() {
        // given
        MockURLProtocol.responseWithStatusCode(code: 200)

        let expectation = XCTestExpectation(description: "Register App")

        // when
        NetworkConnection.register(prefsURL: "http://192.168.2.16", deviceToken: "", deviceId: "", deviceName: "") { response in
            XCTAssertEqual(response.response?.statusCode, 200)
            expectation.fulfill()
        }
        // then
        wait(for: [expectation], timeout: 3)
    }

    func testSitemap() {
        // given
        MockURLProtocol.responseWithStatusCode(code: 200)

        let expectation = XCTestExpectation(description: "Register App")

        // when
        NetworkConnection.sitemaps(openHABRootUrl: "") { response in
            XCTAssertEqual(response.response?.statusCode, 200)
            expectation.fulfill()
        }
        // then
        wait(for: [expectation], timeout: 3)
    }

    func testTracker() {
        // given
        MockURLProtocol.responseWithStatusCode(code: 200)

        let expectation = XCTestExpectation(description: "Register App")

        // when
        NetworkConnection.tracker(openHABRootUrl: "") { response in
            XCTAssertEqual(response.response?.statusCode, 200)
            expectation.fulfill()
        }
        // then
        wait(for: [expectation], timeout: 3)
    }
}
