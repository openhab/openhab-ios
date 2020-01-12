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
    @ObservedObject var settings = UserSettings.shared

    var body: some View {
        List {
            ForEach(viewModel.widgets) { widget in
                self.rowWidget(widget: widget)
                    .environmentObject(self.settings)
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
        Group {
            ContentView(viewModel: UserData())
                .previewDevice("Apple Watch Series 4 - 44mm")
                .environmentObject(UserSettings())

            ContentView(viewModel: UserData(urlString: PreviewConstants.remoteURLString))
                .previewDevice("Apple Watch Series 2 - 38mm")
                .environmentObject(UserSettings(openHABRootUrl: PreviewConstants.remoteURLString))
        }
    }
}
