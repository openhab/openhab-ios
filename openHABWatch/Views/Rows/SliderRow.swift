// Copyright (c) 2010-2024 Contributors to the openHAB project
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
import os.log
import SwiftUI

struct SliderRow: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    @EnvironmentObject var settings: ObservableOpenHABDataObject

    var valueBinding: Binding<Double> {
        .init(
            get: { widget.adjustedValue },
            set: {
                os_log("Slider new value = %g", log: .default, type: .info, $0)
                widget.sendCommand($0.valueText(step: widget.step))
            }
        )
    }

    var body: some View {
        VStack(spacing: 3) {
            HStack {
                IconView(widget: widget, settings: settings)
                TextLabelView(widget: widget)
                Spacer()
                DetailTextLabelView(widget: widget)
            }.padding(.top, 8)

            Slider(value: valueBinding, in: widget.minValue ... widget.maxValue, step: widget.step)
                .labelsHidden()
                .focusable(true)
                .digitalCrownRotation(
                    valueBinding,
                    from: widget.minValue,
                    through: widget.maxValue,
                    by: widget.step,
                    sensitivity: .medium,
                    isHapticFeedbackEnabled: true
                )
        }
    }
}

#Preview {
    let widget = UserData().widgets[3]
    return Group {
        SliderRow(widget: widget)
        SliderRow(widget: widget)
    }
    .environmentObject(ObservableOpenHABDataObject())
}
