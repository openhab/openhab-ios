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

import OpenHABCore
import SwiftUI

struct InputRowInputView: View {
    let input: InputRowInput

    var body: some View {
        switch input.renderingKind {
        case .dateInput:
            DatePickerInputRowInputView(input: input)
        case .textInput:
            TextInputRowInputView(input: input)
        default:
            TextInputRowInputView(input: input)
        }
    }
}
