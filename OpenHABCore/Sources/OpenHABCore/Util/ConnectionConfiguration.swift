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

public struct ConnectionConfiguration: Hashable, Sendable, Codable {
    public var url: String
    public var username: String
    public var password: String
    public var alwaysSendBasicAuth: Bool
    public var ignoreSSL: Bool
    public var priority: Int // Lower is higher priority, 0 is primary

    public init(url: String, username: String, password: String, alwaysSendBasicAuth: Bool = false, ignoreSSL: Bool = false, priority: Int = 10) {
        self.url = url
        self.username = username
        self.password = password
        self.alwaysSendBasicAuth = alwaysSendBasicAuth
        self.ignoreSSL = ignoreSSL
        self.priority = priority
    }
}
