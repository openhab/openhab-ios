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

@Suite("AppGroup")
struct AppGroupTests {
    @Test("Falls back to the official group when the bundle does not declare one")
    func fallsBackToDefault() {
        // The package's resource bundle has no OpenHABAppGroup key.
        #expect(AppGroup.identifier(in: .module) == "group.org.openhab.app")
    }

    @Test("Default is the official openHAB app group")
    func defaultIsOfficialGroup() {
        #expect(AppGroup.defaultIdentifier == "group.org.openhab.app")
    }
}
