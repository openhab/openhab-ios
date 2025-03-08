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

final class TestClient: XCTestCase {
    var transport: TestClientTransport!
    var client: Client {
        get throws {
            try .init(
                serverURL: URL(validatingOpenAPIServerURL: "/api"),
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

    // swiftlint:disable line_length
    func testgetRoot() async throws {
        transport = .init { (request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) in
            XCTAssertEqual(operationID, "getRoot")
            XCTAssertEqual(
                request.path,
                "//"
            )
            XCTAssertEqual(baseURL.absoluteString, "/api")
            XCTAssertEqual(request.method, .get)
            XCTAssertNil(body)
            return try HTTPResponse(
                status: .ok
            )
            .withEncodedBody(
                #"""
                {"version":"8","locale":"en_DE","measurementSystem":"SI","runtimeInfo":{"version":"4.3.2","buildString":"Release Build"},"links":[{"type":"config-descriptions","url":"http://192.168.2.10:8080/rest/config-descriptions"},{"type":"auth","url":"http://192.168.2.10:8080/rest/auth"},{"type":"habpanel","url":"http://192.168.2.10:8080/rest/habpanel"},{"type":"sitemaps","url":"http://192.168.2.10:8080/rest/sitemaps"},{"type":"persistence","url":"http://192.168.2.10:8080/rest/persistence"},{"type":"addons","url":"http://192.168.2.10:8080/rest/addons"},{"type":"things","url":"http://192.168.2.10:8080/rest/things"},{"type":"channel-types","url":"http://192.168.2.10:8080/rest/channel-types"},{"type":"profile-types","url":"http://192.168.2.10:8080/rest/profile-types"},{"type":"module-types","url":"http://192.168.2.10:8080/rest/module-types"},{"type":"links","url":"http://192.168.2.10:8080/rest/links"},{"type":"thing-types","url":"http://192.168.2.10:8080/rest/thing-types"},{"type":"tags","url":"http://192.168.2.10:8080/rest/tags"},{"type":"discovery","url":"http://192.168.2.10:8080/rest/discovery"},{"type":"events","url":"http://192.168.2.10:8080/rest/events"},{"type":"rules","url":"http://192.168.2.10:8080/rest/rules"},{"type":"services","url":"http://192.168.2.10:8080/rest/services"},{"type":"items","url":"http://192.168.2.10:8080/rest/items"},{"type":"actions","url":"http://192.168.2.10:8080/rest/actions"},{"type":"logging","url":"http://192.168.2.10:8080/rest/logging"},{"type":"audio","url":"http://192.168.2.10:8080/rest/audio"},{"type":"voice","url":"http://192.168.2.10:8080/rest/voice"},{"type":"templates","url":"http://192.168.2.10:8080/rest/templates"},{"type":"inbox","url":"http://192.168.2.10:8080/rest/inbox"},{"type":"systeminfo","url":"http://192.168.2.10:8080/rest/systeminfo"},{"type":"ui","url":"http://192.168.2.10:8080/rest/ui"},{"type":"transformations","url":"http://192.168.2.10:8080/rest/transformations"},{"type":"uuid","url":"http://192.168.2.10:8080/rest/uuid"},{"type":"spec","url":"http://192.168.2.10:8080/rest/spec"},{"type":"iconsets","url":"http://192.168.2.10:8080/rest/iconsets"}]}
                """#
            )
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

// swiftlint:enable line_length
