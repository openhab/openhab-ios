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

import CoreGraphics
@testable import openHAB
import Testing

@Suite("MenuSizing")
struct MenuSizingTests {
    @Test("Until the popover has measured its room the menu has its default height")
    func fallbackBeforeMeasured() {
        #expect(MenuSizing.maxHeight(room: nil) == MenuSizing.defaultHeight)
    }

    @Test("The menu may use the room it has, less the space left to tap on")
    func roomLessMargin() {
        #expect(MenuSizing.maxHeight(room: 780) == 780 - MenuSizing.dismissMargin)
    }

    @Test("On a tall display the menu grows well beyond the default height")
    func growsOnTallDisplays() {
        #expect(MenuSizing.maxHeight(room: 780) > MenuSizing.defaultHeight)
    }

    @Test("A little room still leaves a usable menu")
    func neverSmallerThanMinimum() {
        #expect(MenuSizing.maxHeight(room: 100) == MenuSizing.minimumHeight)
        #expect(MenuSizing.maxHeight(room: MenuSizing.dismissMargin) == MenuSizing.minimumHeight)
    }

    @Test("The space left to tap on is enough to tap on")
    func marginIsTappable() {
        #expect(MenuSizing.dismissMargin >= 44)
    }
}
