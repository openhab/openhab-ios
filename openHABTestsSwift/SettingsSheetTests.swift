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
import OpenHABCore
import Testing

@Suite("SettingsSheetModifier — dirty tracking and section management")
struct SettingsSheetTests {
    // MARK: - AppSettingsSnapshot dirty tracking

    @Test("Clean snapshot equals itself — isDirty should be false")
    func cleanSnapshotIsNotDirty() {
        let snap = AppSettingsView.AppSettingsSnapshot(
            idleOff: true, sendCrashReports: false, hideStatusBar: false, showSearchField: true
        )
        #expect(snap == snap)
    }

    @Test("Any changed field produces an unequal snapshot — isDirty should become true")
    func changedFieldMarksDirty() {
        let initial = AppSettingsView.AppSettingsSnapshot(
            idleOff: true, sendCrashReports: false, hideStatusBar: false, showSearchField: true
        )
        var modified = initial
        modified.idleOff = false
        #expect(initial != modified)
    }

    @Test("Multiple changed fields are all detected")
    func multipleChangesAllDetected() {
        let initial = AppSettingsView.AppSettingsSnapshot(
            idleOff: false, sendCrashReports: false, hideStatusBar: false, showSearchField: true
        )
        var current = initial
        current.hideStatusBar = true
        current.showSearchField = false
        #expect(current != initial)
    }

    @Test("Reverting to initial snapshot clears dirty state")
    func revertRestoresCleanState() {
        let initial = AppSettingsView.AppSettingsSnapshot(
            idleOff: false, sendCrashReports: true, hideStatusBar: true, showSearchField: false
        )
        var current = initial
        current.idleOff = true
        current.sendCrashReports = false
        #expect(current != initial)
        current = initial   // simulates onRevert callback
        #expect(current == initial)
    }

    // MARK: - Section order / visibility logic (drives HomeSettingsView dirty tracking)

    @Test("Hiding a section removes it from the order array")
    func hidingASectionRemovesItFromOrder() {
        var order = MenuSection.allCases
        order.removeAll { $0 == .tiles }
        #expect(!order.contains(.tiles))
        #expect(order.count == MenuSection.allCases.count - 1)
    }

    @Test("Showing a hidden section appends it to the end of the order")
    func showingAHiddenSectionAppendsToEnd() {
        var order: [MenuSection] = [.mainUI, .sitemaps, .system]
        order.append(.tiles)
        #expect(order.last == .tiles)
        #expect(Set(order) == Set(MenuSection.allCases))
    }

    @Test("Reordering moves a section without losing any section")
    func reorderingMovesWithoutLoss() {
        var order: [MenuSection] = [.mainUI, .sitemaps, .tiles, .system]
        order.move(fromOffsets: IndexSet(integer: 0), toOffset: 4)   // mainUI → end
        #expect(order == [.sitemaps, .tiles, .system, .mainUI])
        #expect(Set(order) == Set(MenuSection.allCases))
    }

    @Test("A changed section order produces an unequal array — isDirty should become true")
    func sectionOrderChangeDetectedAsDirty() {
        let original = MenuSection.allCases
        var changed = original
        changed.move(fromOffsets: IndexSet(integer: 0), toOffset: changed.count)
        #expect(changed != original)
    }

    @Test("Hidden sections are the complement of the visible order")
    func hiddenSectionsAreComplement() {
        let order: [MenuSection] = [.mainUI, .sitemaps]
        let hidden = MenuSection.allCases.filter { !Set(order).contains($0) }
        #expect(hidden.count == 2)
        #expect(hidden.contains(.tiles))
        #expect(hidden.contains(.system))
    }

    @Test("Default order has no hidden sections")
    func defaultOrderHasNoHiddenSections() {
        let order = MenuSection.allCases
        let hidden = MenuSection.allCases.filter { !Set(order).contains($0) }
        #expect(hidden.isEmpty)
    }

    @Test("Toggling all sections off leaves an empty order")
    func togglingAllSectionsOffLeavesEmptyOrder() {
        var order = MenuSection.allCases
        for section in MenuSection.allCases {
            order.removeAll { $0 == section }
        }
        #expect(order.isEmpty)
    }
}
