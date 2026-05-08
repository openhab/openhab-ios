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
    @ViewBuilder
    func sensoryHeavyFeedbackIfAvailable(trigger: Bool) -> some View {
        if #available(iOS 17.0, *) {
            sensoryFeedback(.impact(weight: .heavy, intensity: 0.9), trigger: trigger)
        } else {
            self
        }
    }

    @ViewBuilder
    func sensoryStopFeedbackIfAvailable(trigger: Bool) -> some View {
        if #available(iOS 17.0, *) {
            sensoryFeedback(.impact(flexibility: .rigid), trigger: trigger)
        } else {
            self
        }
    }

    @ViewBuilder
    func sensorySelectionFeedbackIfAvailable(trigger: Bool) -> some View {
        if #available(iOS 17.0, *) {
            sensoryFeedback(.selection, trigger: trigger)
        } else {
            self
        }
    }
}
