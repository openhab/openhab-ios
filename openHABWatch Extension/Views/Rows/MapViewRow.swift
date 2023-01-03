// Copyright (c) 2010-2023 Contributors to the openHAB project
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

struct MapViewRow: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

    var body: some View {
        VStack {
            MapView(widget: widget)
                .scaledToFit()
                .padding()
            // .frame(height: 300)
        }
    }
}

struct MapViewRow_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[9]
        return MapViewRow(widget: widget)
    }
}
