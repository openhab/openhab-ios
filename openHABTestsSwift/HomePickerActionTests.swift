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

@testable import openHAB
import Testing

struct HomePickerActionTests {
    @Test(arguments: [
        (0, HomePickerAction.addHome), // still loading, or nothing stored
        (1, .addHome),
        (2, .edit),
        (3, .edit)
    ])
    func outsideEditModeDependsOnHomeCount(homeCount: Int, expected: HomePickerAction) {
        #expect(HomePickerAction(homeCount: homeCount, isEditing: false) == expected)
    }

    @Test(arguments: [0, 1, 3])
    func editModeWinsOverHomeCount(homeCount: Int) {
        #expect(HomePickerAction(homeCount: homeCount, isEditing: true) == .editing)
    }
}
