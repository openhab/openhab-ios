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

import Testing

struct StringExtensionTests {
    @Test func testRemoveTrailingSlashes() async throws {
        #expect("example/".removeTrailingSlashes() == "example")
        #expect("example//".removeTrailingSlashes() == "example")
        #expect("example/path//".removeTrailingSlashes() == "example/path")
        #expect("example/path/".removeTrailingSlashes() == "example/path")
        #expect("example/path".removeTrailingSlashes() == "example/path")
        #expect("/".removeTrailingSlashes() == "")
        #expect("///".removeTrailingSlashes() == "")
        #expect("".removeTrailingSlashes() == "")
    }
}
