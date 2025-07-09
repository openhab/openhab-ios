// Copyright (c) 2010-2025 Contributors to the openHAB project
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

struct WidgetSliderView: View {
    let widget: OpenHABWidget

    // Example: assuming widget has a numeric value as text
    var currentValue: Double {
        Double(widget.labelValue ?? "") ?? 0.0
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(widget.labelText ?? "")
                .font(.headline)
            Slider(value: .constant(currentValue), in: 0 ... 100)
                .disabled(true) // unless you want editable
            if let value = widget.labelValue {
                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// #Preview {
//    WidgetSliderView()
// }
