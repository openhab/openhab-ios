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

import MapKit
import OpenHABCore
import SwiftUI

struct MapView: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: 40,
            longitude: -5
        ),
        span: MKCoordinateSpan(
            latitudeDelta: 0.02,
            longitudeDelta: 0.02
        )
    )

    var body: some View {
        Map(coordinateRegion: .constant(
            MKCoordinateRegion(
                center: widget.coordinate,
                latitudinalMeters: 1000.0,
                longitudinalMeters: 1000.0
            )
        )
        )
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[9]
        return MapView(widget: widget)
            .previewDevice("Apple Watch Series 5 - 44mm")
    }
}
