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
import Testing

/// Helper for verbose test logging
enum TestLogger {
    static let enabled = ProcessInfo.processInfo.environment["VERBOSE_TESTS"] == "1"

    static func log(_ message: String) {
        if enabled {
            print("🧪 [TEST] \(message)")
        }
    }

    static func logFormatted(_ label: String, _ value: Any) {
        if enabled {
            print("🧪 [TEST] \(label): \(value)")
        }
    }

    static func logExpectation<T>(_ condition: Bool, expected: T, actual: T) {
        if enabled, !condition {
            print("❌ [TEST FAILED]")
            print("   Expected: \(expected)")
            print("   Actual: \(actual)")
        }
    }
}
