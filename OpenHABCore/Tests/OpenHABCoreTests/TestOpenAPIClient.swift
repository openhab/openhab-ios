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

import HTTPTypes
import OpenAPIRuntime
import OpenHABCore
import XCTest

final class TestOpenAPIClient: XCTestCase {
    var transport: TestClientTransport!
    var client: Client {
        get throws {
            try .init(
                serverURL: URL(validatingOpenAPIServerURL: "/rest"),
                configuration: .init(multipartBoundaryGenerator: .constant),
                transport: transport
            )
        }
    }

    /// Setup method called before the invocation of each test method in the class.
    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
    }

    func testgetRoot() async throws {
        transport = .init { (request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) in
            XCTAssertEqual(operationID, "getRoot")
            XCTAssertEqual(
                request.path,
                "/"
            )
            XCTAssertEqual(baseURL.absoluteString, "/rest")
            XCTAssertEqual(request.method, .get)
            XCTAssertNil(body)
            return try HTTPResponse.listRootSuccess
        }
        let response = try await client.getRoot()
        guard case let .ok(value) = response else {
            XCTFail("Unexpected response: \(response)")
            return
        }
        switch value.body {
        case let .json(rootBean): XCTAssertEqual(rootBean.version, "8")
        }
    }
}
