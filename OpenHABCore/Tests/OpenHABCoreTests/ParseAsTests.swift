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

@testable import OpenHABCore
import Testing

struct ParseAsTests {
    @Test func parseAsBool() {
        #expect("10,10,0".parseAsBool() == false)
        #expect("10,10,50".parseAsBool() == true)
    }

    @Test func validOpenHABURL() throws {
        try "http://localhost:8080".testAsValidOpenHABURL()
        try "https://localhost:8080".testAsValidOpenHABURL()
        try "192.168.2.10".testAsValidOpenHABURL()
    }

    @Test func invalidOpenHABURL() {
        let invalidURLs = [
            "ftp://localhost", // Unsupported scheme
            "http:/localhost", // Malformed
            "http://", // Missing host
            "://localhost", // Missing scheme
            "file:///Users/me", // Unsupported scheme
            "https://" // No host
        ]

        for url in invalidURLs {
            #expect {
                try url.testAsValidOpenHABURL()
            } throws: { error in
                guard let urlError = error as? URLError else { return false }
                return urlError.code == .badURL
            }
        }
    }
}
