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

import SwiftUI

/// Contract that settings sheets must satisfy to use the shared toolbar and dismiss guard.
/// Adopt this protocol on a `View`, then apply `.settingsSheet(from: self)` in the body.
///
/// Default implementations are provided for `isDirty` (computed as `current != initial`)
/// and `onRevert` (resets `current` to `initial`). Override `onRevert` when additional
/// side-effects are needed (e.g. discarding an in-memory image crop).
protocol SettingsSheetView: View {
    associatedtype Snapshot: Equatable
    /// The live settings state bound to the form controls.
    var current: Snapshot { get set }
    /// The settings state as loaded from storage — used for dirty comparison and revert.
    var initial: Snapshot { get }
    /// Persist changes and dismiss the sheet.
    func onSave()
    /// Restore all fields to their initial loaded state without closing.
    func onRevert()
    /// Discard unsaved changes and dismiss the sheet.
    func onCancel()
}

extension SettingsSheetView {
    /// `true` when `current` differs from `initial`. Recomputed on every render.
    /// Reading `current` and `initial` is non-mutating so this works in a protocol extension.
    var isDirty: Bool { current != initial }
}

struct SettingsSheetModifier: ViewModifier {
    var isDirty: Bool
    var onSave: () -> Void
    var onRevert: () -> Void
    var onCancel: () -> Void

    // Animated mirror of `isDirty`. Using a separate @State (driven via withAnimation in
    // onChange) ensures the toolbar items are added/removed from the hierarchy — not just
    // made transparent — so the Liquid Glass backing disappears along with the buttons.
    @State private var showsDirtyButtons = false

    func body(content: Content) -> some View {
        content
            .interactiveDismissDisabled(isDirty)
            .onAppear { showsDirtyButtons = isDirty }
            .onChange(of: isDirty) { _, new in
                withAnimation(.easeInOut(duration: 0.2)) { showsDirtyButtons = new }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if showsDirtyButtons {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { onRevert() }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }

                        Button(action: onSave) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
    }
}

extension View {
    /// Applies the settings-sheet toolbar and dismiss guard using a `SettingsSheetView`.
    /// The modifier reads `isDirty` and the three action callbacks directly from the
    /// conforming view, so the call site is simply `.settingsSheet(from: self)`.
    func settingsSheet<S: SettingsSheetView>(from view: S) -> some View {
        modifier(SettingsSheetModifier(
            isDirty: view.isDirty,
            onSave: view.onSave,
            onRevert: view.onRevert,
            onCancel: view.onCancel
        ))
    }
}
