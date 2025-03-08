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
import OpenAPIRuntime
import XCTest

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
import Foundation
import OpenAPIRuntime
import XCTest

/// Asserts that the stringified data matches the expected string value.
public func XCTAssertEqualStringifiedData(_ expression1: @autoclosure () throws -> Data?,
                                          _ expression2: @autoclosure () throws -> String,
                                          _ message: @autoclosure () -> String = "",
                                          file: StaticString = #filePath,
                                          line: UInt = #line) {
    do {
        guard let value1 = try expression1() else {
            XCTFail("First value is nil", file: file, line: line)
            return
        }
        let actualString = String(decoding: value1, as: UTF8.self)
        XCTAssertEqual(actualString, try expression2(), file: file, line: line)
    } catch { XCTFail(error.localizedDescription, file: file, line: line) }
}

/// Asserts that the stringified data matches the expected string value.
public func XCTAssertEqualStringifiedData(_ expression1: @autoclosure () throws -> (some Sequence<UInt8>)?,
                                          _ expression2: @autoclosure () throws -> String,
                                          _ message: @autoclosure () -> String = "",
                                          file: StaticString = #filePath,
                                          line: UInt = #line) {
    do {
        guard let value1 = try expression1() else {
            XCTFail("First value is nil", file: file, line: line)
            return
        }
        let actualString = String(decoding: Array(value1), as: UTF8.self)
        XCTAssertEqual(actualString, try expression2(), file: file, line: line)
    } catch { XCTFail(error.localizedDescription, file: file, line: line) }
}

/// Asserts that the stringified data matches the expected string value.
public func XCTAssertEqualStringifiedData(_ expression1: @autoclosure () throws -> HTTPBody?,
                                          _ expression2: @autoclosure () throws -> String,
                                          _ message: @autoclosure () -> String = "",
                                          file: StaticString = #filePath,
                                          line: UInt = #line) async throws {
    let data: Data = if let body = try expression1() { try await Data(collecting: body, upTo: .max) } else { .init() }
    XCTAssertEqualStringifiedData(data, try expression2(), message(), file: file, line: line)
}

private extension UInt8 {
    var asHex: String {
        let original = switch self {
        case 0x0D: "CR"
        case 0x0A: "LF"
        default: "\(UnicodeScalar(self)) "
        }
        return String(format: "%02x \(original)", self)
    }
}

/// Asserts that the data matches the expected value.
public func XCTAssertEqualData(_ expression1: @autoclosure () throws -> (some Collection<UInt8>)?,
                               _ expression2: @autoclosure () throws -> some Collection<UInt8>,
                               _ message: @autoclosure () -> String = "Data doesn't match.",
                               file: StaticString = #filePath,
                               line: UInt = #line) {
    do {
        guard let actualBytes = try expression1() else {
            XCTFail("First value is nil", file: file, line: line)
            return
        }
        let expectedBytes = try expression2()
        if ArraySlice(actualBytes) == ArraySlice(expectedBytes) { return }
        let actualCount = actualBytes.count
        let expectedCount = expectedBytes.count
        let minCount = min(actualCount, expectedCount)
        print("Printing both byte sequences, first is the actual value and second is the expected one.")
        for (index, byte) in zip(actualBytes.prefix(minCount), expectedBytes.prefix(minCount)).enumerated() {
            print("\(String(format: "%04d", index)): \(byte.0 != byte.1 ? "x" : " ") \(byte.0.asHex) | \(byte.1.asHex)")
        }
        let direction: String
        let extraBytes: ArraySlice<UInt8>
        if actualCount > expectedCount {
            direction = "Actual bytes has extra bytes"
            extraBytes = ArraySlice(actualBytes.dropFirst(minCount))
        } else if expectedCount > actualCount {
            direction = "Actual bytes is missing expected bytes"
            extraBytes = ArraySlice(expectedBytes.dropFirst(minCount))
        } else {
            direction = ""
            extraBytes = []
        }
        if !extraBytes.isEmpty {
            print("\(direction):")
            for (index, byte) in extraBytes.enumerated() {
                print("\(String(format: "%04d", minCount + index)): \(byte.asHex)")
            }
        }
        XCTFail(
            "Actual stringified data '\(String(decoding: actualBytes, as: UTF8.self))' doesn't equal to expected stringified data '\(String(decoding: expectedBytes, as: UTF8.self))'. Details: \(message())",
            file: file,
            line: line
        )
    } catch { XCTFail(error.localizedDescription, file: file, line: line) }
}

/// Asserts that the data matches the expected value.
public func XCTAssertEqualData(_ expression1: @autoclosure () throws -> HTTPBody?,
                               _ expression2: @autoclosure () throws -> some Collection<UInt8>,
                               _ message: @autoclosure () -> String = "Data doesn't match.",
                               file: StaticString = #filePath,
                               line: UInt = #line) async throws {
    let data: Data = if let body = try expression1() { try await Data(collecting: body, upTo: .max) } else { .init() }
    XCTAssertEqualData(data, try expression2(), message(), file: file, line: line)
}
