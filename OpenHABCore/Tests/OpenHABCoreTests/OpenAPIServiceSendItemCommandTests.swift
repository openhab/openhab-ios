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
import HTTPTypes
import OpenAPIRuntime
import OpenHABCore
import Testing

@Suite
struct OpenAPIServiceSendItemCommandTests {
    @Test("sendItemCommand uses application/json with object payload")
    func sendItemCommandUsesJSONPayload() async throws {
        let transport = TestClientTransport { request, body, baseURL, operationID in
            #expect(operationID == "sendItemCommand")
            #expect(request.method == .post)
            #expect(request.path == "/items/MyItem")
            #expect(baseURL.absoluteString == "/rest")
            #expect(request.headerFields[.contentType] == "application/json; charset=utf-8")
            #expect(try await encodedBody(from: body) == #"{"value":"ON"}"#)

            return (try HTTPResponse(status: .ok), nil)
        }
        let client = try Client(
            serverURL: URL(validatingOpenAPIServerURL: "/rest"),
            configuration: .init(multipartBoundaryGenerator: .constant),
            transport: transport
        )
        let service = OpenAPIService(client: client)

        try await service.sendItemCommand(itemname: "MyItem", command: "ON")
    }

    private func encodedBody(from body: HTTPBody?) async throws -> String {
        guard let body else {
            throw TestError.unexpectedMissingRequestBody
        }

        var bytes = [UInt8]()
        for try await chunk in body {
            bytes.append(contentsOf: chunk)
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
