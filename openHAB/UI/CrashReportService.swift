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
import Observation
import OpenHABCore

@MainActor
@Observable
final class CrashReportService {
    var crashReportAlert = false

    // MARK: - Crash Report

    /// Shows the crash report alert if the previous run crashed and the user has not
    /// already opted in to sending reports. Called from the view's `.task` rather than
    /// `init`, because `@State` may construct (and discard) extra instances.
    func checkForPreviousCrash(didCrash: Bool = Crashlytics.crashlytics().didCrashDuringPreviousExecution(),
                               isReportingEnabled: @Sendable () async -> Bool = { await Preferences.shared.sendCrashReports }) async {
        guard didCrash else { return }
        if await !isReportingEnabled() {
            crashReportAlert = true
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
