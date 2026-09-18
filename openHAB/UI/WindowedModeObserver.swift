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
import UIKit

/// Tracks whether the app's window currently occupies less than the whole screen on iPad
/// (Stage Manager, Split View/Slide Over, or a freely resized windowed session).
///
/// In that state the system draws its own window controls over the top-left corner of the
/// app's content without reserving a safe-area inset for them, so callers use `isWindowed`
/// to reserve extra leading space by hand instead.
///
/// Apply to a view that fills the window (e.g. the root content) — `isWindowed` is derived
/// from that view's own laid-out size, compared against the screen it's presented on.
private struct WindowedModeObserver: ViewModifier {
    @Binding var isWindowed: Bool

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { _, windowSize in
                update(windowSize: windowSize)
            }
    }

    private func update(windowSize: CGSize) {
        guard let windowScene = UIApplication.shared.firstKeyWindow?.windowScene,
              windowScene.traitCollection.userInterfaceIdiom == .pad else {
            isWindowed = false
            return
        }
        let screenSize = windowScene.screen.bounds.size
        isWindowed = windowSize.width < screenSize.width - 1 || windowSize.height < screenSize.height - 1
    }
}

extension View {
    /// See `WindowedModeObserver`.
    func onWindowedModeChange(_ isWindowed: Binding<Bool>) -> some View {
        modifier(WindowedModeObserver(isWindowed: isWindowed))
    }
}
