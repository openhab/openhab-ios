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

@Suite("CrashReportService")
@MainActor
struct CrashReportServiceTests {
    @Test("Alert is off before the crash check runs")
    func alertOffInitially() {
        #expect(CrashReportService().crashReportAlert == false)
    }

    @Test(
        "Alert shows only after a crash when reporting is not enabled",
        arguments: [
            (didCrash: true, isReportingEnabled: false, expectsAlert: true),
            (didCrash: true, isReportingEnabled: true, expectsAlert: false),
            (didCrash: false, isReportingEnabled: false, expectsAlert: false),
            (didCrash: false, isReportingEnabled: true, expectsAlert: false)
        ]
    )
    func alertDecision(didCrash: Bool, isReportingEnabled: Bool, expectsAlert: Bool) async {
        let service = CrashReportService()

        await service.checkForPreviousCrash(didCrash: didCrash) { isReportingEnabled }

        #expect(service.crashReportAlert == expectsAlert)
    }
}
