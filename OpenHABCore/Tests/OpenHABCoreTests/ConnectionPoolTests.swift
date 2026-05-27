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
@testable import OpenHABCore
import Testing

struct ConnectionPoolTests {
    @Test func getOrCreateServiceReturnsSameInstance() async throws {
        let pool = ConnectionPool()
        let config = ConnectionConfiguration(url: "http://test", username: "", password: "", priority: 1)

        let service1 = try await pool.getOrCreateService(for: config)
        let service2 = try await pool.getOrCreateService(for: config)

        #expect(service1 === service2)
    }
}
