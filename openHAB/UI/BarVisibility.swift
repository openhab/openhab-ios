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

import Observation
import SwiftUI

// MARK: - Hiding the bars

//
// The "Hide Status Bar" setting hides the status bar and the navigation bar with the menu button,
// so a wall-mounted tablet or a dedicated phone shows nothing but the page (issue #1375).
//
// DECISIONS
// - Hidden bars must never leave the user stuck. Holding three fingers on the screen shows them
//   again for a few seconds (`ThreeFingerHoldRecognizer`), and they stay while the menu is open.
// - Under Guided Access the bars are hidden whatever the setting says, and the gesture is off:
//   the way out is the system's own, triple-clicking the side button, which asks for the
//   passcode that the person who set the device up chose.
// - The bars are also shown while there is nothing to look at but an error (`needsBars`: no
//   connection, or the page has not loaded), because the connection indicator is in the bar.
// - One model for the whole app, read through the environment, so Main UI, tiles and every
//   sitemap page hide and show together.

/// Whether the status bar and the navigation bar are hidden right now.
@MainActor @Observable
final class BarVisibility {
    /// How long a reveal lasts without another one.
    nonisolated static let defaultRevealDuration = Duration.seconds(8)

    /// The reveal time a launch uses. UI tests shorten it with `UITestBarRevealSeconds`.
    nonisolated static var launchRevealDuration: Duration {
        #if DEBUG
        if let seconds = ProcessInfo.processInfo.environment["UITestBarRevealSeconds"].flatMap(Double.init) {
            return .seconds(seconds)
        }
        #endif
        return defaultRevealDuration
    }

    /// Whether the device is under Guided Access. A UI test decides for itself.
    @MainActor
    static var isGuidedAccessEnabled: Bool {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if env["UITest"] != nil {
            return env["UITestGuidedAccess"] != nil
        }
        #endif
        return UIAccessibility.isGuidedAccessEnabled
    }

    /// The app setting: hide the bars unless something asks for them.
    var hidesBars = false
    /// The device is locked to the app by Guided Access, iOS's own kiosk mode.
    var isInGuidedAccess = false
    /// Something is wrong or still loading, and the bar carries the indicator for it.
    var needsBars = false
    /// The menu is open, so the bar it came from has to stay.
    var menuIsOpen = false
    private(set) var isRevealed = false

    var isHidden: Bool {
        guard !needsBars, !menuIsOpen else { return false }
        return isInGuidedAccess || (hidesBars && !isRevealed)
    }

    /// Whether holding three fingers does anything. Guided Access has its own way out.
    var allowsReveal: Bool {
        hidesBars && !isInGuidedAccess
    }

    private let revealDuration: Duration
    private let sleep: @Sendable (Duration) async throws -> Void
    private(set) var revealTask: Task<Void, Never>?

    /// The sleep is a parameter so a test does not have to wait for the reveal to end.
    init(revealDuration: Duration = BarVisibility.defaultRevealDuration,
         sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.revealDuration = revealDuration
        self.sleep = sleep
    }

    /// Shows the bars for `revealDuration`. Revealing again starts the time over.
    func reveal() {
        guard allowsReveal else { return }
        revealTask?.cancel()
        isRevealed = true
        revealTask = Task { [sleep, revealDuration] in
            do {
                try await sleep(revealDuration)
            } catch {
                return
            }
            expire()
        }
    }

    /// The end of a reveal. Separate from the timer so that it can be tested directly.
    func expire() {
        revealTask = nil
        isRevealed = false
    }
}

extension EnvironmentValues {
    /// Nil where no one hides the bars, e.g. in a preview.
    @Entry var barVisibility: BarVisibility?
}

extension View {
    /// Hides the navigation bar of the enclosing `NavigationStack` while the app hides its bars.
    func hidesNavigationBarWithApp() -> some View {
        modifier(AppHiddenNavigationBar())
    }
}

private struct AppHiddenNavigationBar: ViewModifier {
    @Environment(\.barVisibility) private var bars

    func body(content: Content) -> some View {
        content
            .toolbarVisibility(bars?.isHidden == true ? .hidden : .visible, for: .navigationBar)
            .animation(.default, value: bars?.isHidden)
    }
}
