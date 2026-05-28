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

extension View {
    func sensoryHeavyFeedbackIfAvailable(trigger: Bool) -> some View {
        sensoryFeedback(.impact(weight: .heavy, intensity: 0.9), trigger: trigger)
    }

    func sensoryStopFeedbackIfAvailable(trigger: Bool) -> some View {
        sensoryFeedback(.impact(flexibility: .rigid), trigger: trigger)
    }

    func sensorySelectionFeedbackIfAvailable(trigger: Bool) -> some View {
        sensoryFeedback(.selection, trigger: trigger)
    }
}
