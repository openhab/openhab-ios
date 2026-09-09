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

import FirebaseCrashlytics
import OpenHABCore
import SwiftUI

@MainActor
class CrashReportService: ObservableObject {
    // MARK: - Published state

    @Published var crashReportAlert = false

    init() {
        setupCrashReportCheck()
    }

    // MARK: - Crash Report

    private func setupCrashReportCheck() {
        Task { @MainActor in
            if Crashlytics.crashlytics().didCrashDuringPreviousExecution(), !(await Preferences.shared.sendCrashReports) {
                crashReportAlert = true
            }
        }
    }

    func enableCrashReporting() {
        Task {
            await Preferences.shared.setSendCrashReports(true)
            Crashlytics.crashlytics().sendUnsentReports()
        }
    }

    func deleteCrashReports() {
        Crashlytics.crashlytics().deleteUnsentReports()
    }
}
