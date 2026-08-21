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

import AppIntents
import OpenHABCore

struct SetActiveHomeIntent: AppIntent {
    static var openAppWhenRun: Bool {
        false
    }

    static let title: LocalizedStringResource = "Set Active Home"
    static let description = IntentDescription("Switch the active home in the openHAB app")

    static var parameterSummary: some ParameterSummary {
        Summary("Set active home to \(\.$home)")
    }

    @Parameter(title: "Home")
    var home: Home

    func perform() async throws -> some IntentResult {
        try await MainActor.run {
            let storedHomes = Preferences.shared.storedHomes
            guard let localUUID = Home.resolveStoredHomeKey(for: home.id, in: storedHomes) else {
                throw HomeResolutionError.unknownHome
            }
            Preferences.shared.switchActiveHome(to: localUUID)
        }
        return .result()
    }
}
