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

struct SegmentRow: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    @EnvironmentObject var settings: ObservableOpenHABDataObject

    @State private var favoriteColor = 0

    var valueBinding: Binding<Int> {
        .init(
            get: {
                guard case let .segmented(value) = widget.stateEnumBinding else { return 0 }
                return value
            },
            set: {
                os_log("Slider new value = %g", log: .default, type: .info, $0)
                // self.widget.sendCommand($0)
                widget.stateEnumBinding = .segmented($0)
            }
        )
    }

    var body: some View {
        VStack {
            HStack {
                IconView(widget: widget, settings: settings)
                TextLabelView(widget: widget)
                Spacer()
                DetailTextLabelView(widget: widget)
            }
            Picker("Picker", selection: valueBinding) {
                ForEach(0 ..< widget.mappingsOrItemOptions.count, id: \.self) {
                    Text(widget.mappingsOrItemOptions[$0].label).tag($0)
                }
            }
            .labelsHidden()
            .frame(height: 100)
            .padding(.top, 0)
        }
    }
}

#Preview {
    let widget = UserData().widgets[4]
    return Group {
        SegmentRow(widget: widget)
        SegmentRow(widget: widget)
    }
    .environmentObject(ObservableOpenHABDataObject())
}
