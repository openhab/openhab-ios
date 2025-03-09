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

import Foundation
import HTTPTypes
import OpenAPIRuntime

// ===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftOpenAPIGenerator open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftOpenAPIGenerator project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftOpenAPIGenerator project authors
//
// SPDX-License-Identifier: Apache-2.0
//
// ===----------------------------------------------------------------------===//

public enum TestError: Swift.Error, LocalizedError, CustomStringConvertible, Sendable {
    case noHandlerFound(method: HTTPRequest.Method, path: String)
    case invalidURLString(String)
    case unexpectedValue(any Sendable)
    case unexpectedMissingRequestBody

    /// A human-readable description of the error.
    public var description: String {
        switch self {
        case let .noHandlerFound(method, path): "No handler found for method \(method) and path \(path)"
        case let .invalidURLString(string): "Invalid URL string: \(string)"
        case let .unexpectedValue(value): "Unexpected value: \(value)"
        case .unexpectedMissingRequestBody: "Unexpected missing request body"
        }
    }

    /// A localized description of the error suitable for presenting to the user.
    public var errorDescription: String? { description }
}

public extension Date {
    static var test: Date { Date(timeIntervalSince1970: 1_674_036_251) }

    static var testString: String { "2023-01-18T10:04:11Z" }
}

public extension HTTPResponse {
    static var listRootSuccess: (HTTPResponse, HTTPBody) {
        get throws {
            // swiftlint:disable line_length
            try Self(status: .ok, headerFields: [.contentType: "application/json"])
                .withEncodedBody(
                    #"""
                    {"version":"8","locale":"en_DE","measurementSystem":"SI","runtimeInfo":{"version":"4.3.2","buildString":"Release Build"},"links":[{"type":"config-descriptions","url":"http://192.168.2.10:8080/rest/config-descriptions"},{"type":"auth","url":"http://192.168.2.10:8080/rest/auth"},{"type":"habpanel","url":"http://192.168.2.10:8080/rest/habpanel"},{"type":"sitemaps","url":"http://192.168.2.10:8080/rest/sitemaps"},{"type":"persistence","url":"http://192.168.2.10:8080/rest/persistence"},{"type":"addons","url":"http://192.168.2.10:8080/rest/addons"},{"type":"things","url":"http://192.168.2.10:8080/rest/things"},{"type":"channel-types","url":"http://192.168.2.10:8080/rest/channel-types"},{"type":"profile-types","url":"http://192.168.2.10:8080/rest/profile-types"},{"type":"module-types","url":"http://192.168.2.10:8080/rest/module-types"},{"type":"links","url":"http://192.168.2.10:8080/rest/links"},{"type":"thing-types","url":"http://192.168.2.10:8080/rest/thing-types"},{"type":"tags","url":"http://192.168.2.10:8080/rest/tags"},{"type":"discovery","url":"http://192.168.2.10:8080/rest/discovery"},{"type":"events","url":"http://192.168.2.10:8080/rest/events"},{"type":"rules","url":"http://192.168.2.10:8080/rest/rules"},{"type":"services","url":"http://192.168.2.10:8080/rest/services"},{"type":"items","url":"http://192.168.2.10:8080/rest/items"},{"type":"actions","url":"http://192.168.2.10:8080/rest/actions"},{"type":"logging","url":"http://192.168.2.10:8080/rest/logging"},{"type":"audio","url":"http://192.168.2.10:8080/rest/audio"},{"type":"voice","url":"http://192.168.2.10:8080/rest/voice"},{"type":"templates","url":"http://192.168.2.10:8080/rest/templates"},{"type":"inbox","url":"http://192.168.2.10:8080/rest/inbox"},{"type":"systeminfo","url":"http://192.168.2.10:8080/rest/systeminfo"},{"type":"ui","url":"http://192.168.2.10:8080/rest/ui"},{"type":"transformations","url":"http://192.168.2.10:8080/rest/transformations"},{"type":"uuid","url":"http://192.168.2.10:8080/rest/uuid"},{"type":"spec","url":"http://192.168.2.10:8080/rest/spec"},{"type":"iconsets","url":"http://192.168.2.10:8080/rest/iconsets"}]}
                    """#
                )
            // swiftlint:enable line_length
        }
    }

    func withEncodedBody(_ encodedBody: String) throws -> (HTTPResponse, HTTPBody) { (self, .init(encodedBody)) }
}

public extension Data {
    static var abcdString: String { "abcd" }

    static var abcd: Data { Data(abcdString.utf8) }

    static var efghString: String { "efgh" }

    static var quotedEfghString: String { #""efgh""# }

    static var efgh: Data { Data(efghString.utf8) }

    static let crlf: ArraySlice<UInt8> = [0xD, 0xA]

    static var multipartBodyString: String { String(decoding: multipartBodyAsSlice, as: UTF8.self) }

    static var multipartBodyAsSlice: [UInt8] {
        var bytes: [UInt8] = []
        bytes.append(contentsOf: "--__X_SWIFT_OPENAPI_GENERATOR_BOUNDARY__".utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: #"content-disposition: form-data; name="efficiency""#.utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: #"content-length: 3"#.utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: "4.2".utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: "--__X_SWIFT_OPENAPI_GENERATOR_BOUNDARY__".utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: #"content-disposition: form-data; name="name""#.utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: #"content-length: 21"#.utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: "Vitamin C and friends".utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: "--__X_SWIFT_OPENAPI_GENERATOR_BOUNDARY__--".utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: crlf)
        return bytes
    }

    static var multipartBody: Data { Data(multipartBodyAsSlice) }

    static var multipartTypedBodyAsSlice: [UInt8] {
        var bytes: [UInt8] = []
        bytes.append(contentsOf: "--__X_SWIFT_OPENAPI_GENERATOR_BOUNDARY__".utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: #"content-disposition: form-data; filename="process.log"; name="log""#.utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: #"content-length: 35"#.utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: #"content-type: text/plain"#.utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: #"x-log-type: unstructured"#.utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: "here be logs!\nand more lines\nwheee\n".utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: "--__X_SWIFT_OPENAPI_GENERATOR_BOUNDARY__".utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: #"content-disposition: form-data; filename="fun.stuff"; name="keyword""#.utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: #"content-length: 3"#.utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: #"content-type: text/plain"#.utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: "fun".utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: "--__X_SWIFT_OPENAPI_GENERATOR_BOUNDARY__".utf8)

        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: #"content-disposition: form-data; filename="barfoo.txt"; name="foobar""#.utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: #"content-length: 0"#.utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: "".utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: "--__X_SWIFT_OPENAPI_GENERATOR_BOUNDARY__".utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: #"content-disposition: form-data; name="metadata""#.utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: #"content-length: 42"#.utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: #"content-type: application/json; charset=utf-8"#.utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: "{\n  \"createdAt\" : \"2023-01-18T10:04:11Z\"\n}".utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: "--__X_SWIFT_OPENAPI_GENERATOR_BOUNDARY__".utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: #"content-disposition: form-data; name="keyword""#.utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: #"content-length: 3"#.utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: #"content-type: text/plain"#.utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: "joy".utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: "--__X_SWIFT_OPENAPI_GENERATOR_BOUNDARY__".utf8)
        bytes.append(contentsOf: "--".utf8)
        bytes.append(contentsOf: crlf)
        bytes.append(contentsOf: crlf)
        return bytes
    }

    var pretty: String { String(decoding: self, as: UTF8.self) }
}

public extension HTTPRequest {
    func withEncodedBody(_ encodedBody: String) -> (HTTPRequest, HTTPBody) { (self, .init(encodedBody)) }
}
