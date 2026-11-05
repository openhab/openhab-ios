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
@testable import openHAB
import OpenHABCore
import Testing

@Suite("PushRegistrationService.registrationConnection")
struct PushRegistrationServiceTests {
    private static let local = ConnectionConfiguration(url: "http://192.168.2.10:8080", username: "", password: "", supportsNotifications: false, priority: 0)

    private static func cloud(username: String, password: String) -> ConnectionConfiguration {
        ConnectionConfiguration(url: "https://myopenhab.org", username: username, password: password, supportsNotifications: true, priority: 1)
    }

    @Test("Registers a home whose notification connection has a username and a password")
    func registersWithCredentials() {
        let cloud = Self.cloud(username: "user@example.com", password: "secret")
        #expect(PushRegistrationService.registrationConnection(of: [Self.local, cloud], home: UUID()) == cloud)
    }

    @Test("Skips a home whose notification connection lacks credentials", arguments: [("", ""), ("user@example.com", ""), ("", "secret")])
    func skipsWithoutCredentials(username: String, password: String) {
        let cloud = Self.cloud(username: username, password: password)
        #expect(PushRegistrationService.registrationConnection(of: [Self.local, cloud], home: UUID()) == nil)
    }

    @Test("Skips a home without a notification connection")
    func skipsWithoutNotificationConnection() {
        #expect(PushRegistrationService.registrationConnection(of: [Self.local, nil], home: UUID()) == nil)
    }
}
