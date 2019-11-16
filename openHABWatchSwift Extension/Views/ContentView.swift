// Copyright (c) 2010-2019 Contributors to the openHAB project
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

// swiftlint:disable file_types_order
struct ContentView: View {
    @ObservedObject var viewModel: UserData
    @EnvironmentObject var openHABDataObject: ObservableOpenHABDataObject

    var body: some View {
        return List {
            ForEach(viewModel.widgets) { widget in
                self.rowWidget(widget: widget)
                    .environmentObject(self.openHABDataObject)
            }
        }
    }

    func rowWidget(widget: ObservableOpenHABWidget) -> AnyView? {
        switch widget.type {
        case "Switch":
            return AnyView(SwitchRow(widget: widget))
        default:
            return nil
        }
    }
}

extension ContentView {
    init(urlString: String) {
        viewModel = UserData(urlString: urlString)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        return Group {
            ContentView(viewModel: UserData())
                .previewDevice("Apple Watch Series 4 - 44mm")

            ContentView(viewModel: UserData(urlString: "http://192.168.2.15:8081"))
                .previewDevice("Apple Watch Series 2 - 38mm")
        }
    }
}
