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

import Combine
import OpenHABCore
import SwiftUI
import UIKit
import AsyncAlgorithms

/// Service for managing the device's idle timer based on user preferences
@MainActor
class IdleTimerService {
    static let shared = IdleTimerService()
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        observePreferences()
        observeAppLifecycle()
    }
    
    private func observePreferences() {
        // Observe changes to idle timer preference
        Task {
            let channel = await Preferences.shared.applicationPreferencesChannel
            for await preferences in channel {
                configure(idleOff: preferences.idleOff)
            }
        }
    }
    
    private func observeAppLifecycle() {
        // Disable idle timer when entering background
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.disableIdleTimer()
            }
            .store(in: &cancellables)
        
        // Re-enable based on preferences when becoming active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    let preferences = await Preferences.shared.applicationPreferences
                    self?.configure(idleOff: preferences.idleOff)
                }
            }
            .store(in: &cancellables)
    }
    
    /// Configure the idle timer based on user preference
    func configure(idleOff: Bool) {
        UIApplication.shared.isIdleTimerDisabled = idleOff
    }
    
    /// Disable the idle timer (used when entering background)
    func disableIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = false
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Automatically manages the idle timer based on user preferences
    func idleTimerManagement() -> some View {
        self.onAppear {
            // Initialize the service
            _ = IdleTimerService.shared
        }
    }
}
