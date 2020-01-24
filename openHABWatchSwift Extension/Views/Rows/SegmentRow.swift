// Copyright (c) 2010-2020 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import OpenHABCoreWatch
import os.log
import SwiftUI

// swiftlint:disable file_types_order
struct SegmentRow: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

    @State private var favoriteColor = 0
    var body: some View {

        let valueBinding = Binding<Int>(
            get: {
                guard case let .segmented(value) = self.widget.stateEnumBinding else { return 0 }
                return value
            },
            set: {
                os_log("Slider new value = %g", log: .default, type: .info, $0)
                // self.widget.sendCommand($0)
                self.widget.stateEnumBinding = .segmented($0)
            }
        )
        return
            VStack {
                HStack {
                    IconView(widget: widget, settings: settings)
                    TextLabelView(widget: widget)
                    Spacer()
                    DetailTextLabelView(widget: widget)
                }
                Picker("Picker", selection: valueBinding) {
                    ForEach(0 ..< widget.mappingsOrItemOptions.count) {
                        Text(self.widget.mappingsOrItemOptions[$0].label).tag($0)
                    }
                }
                .labelsHidden()
                .frame(height: 100)
                .padding(.top, 0)

            }
    }
}

struct SegmentRow_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[4]
        return Group {
            SegmentRow(widget: widget)
                .previewLayout(.fixed(width: 300, height: 70))
            SegmentRow(widget: widget)
                .previewDevice("Apple Watch Series 4 - 44mm")
        }
    }
}
