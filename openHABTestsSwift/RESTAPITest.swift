// Copyright (c) 2010-2022 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

@testable import Alamofire
@testable import OpenHABCore
import XCTest

class RESTAPITest: XCTestCase {
    override func setUp() {
        super.setUp()

        let manager: Session = {
            let configuration: URLSessionConfiguration = {
                let configuration = URLSessionConfiguration.default
                configuration.protocolClasses = [MockURLProtocol.self]
                return configuration
            }()

            return Session(configuration: configuration)
        }()

        class MockURLRequestAdapter: RequestAdapter {
            func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {}
        }

        NetworkConnection.shared = NetworkConnection(
            ignoreSSL: true,
            manager: manager
        )
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
            .validate()
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
