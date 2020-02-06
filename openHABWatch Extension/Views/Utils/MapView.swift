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

import MapKit
import OpenHABCoreWatch
import SwiftUI
import UIKit

// swiftlint:disable file_types_order
struct MapView: WKInterfaceObjectRepresentable {
    @ObservedObject var widget: ObservableOpenHABWidget

    func makeWKInterfaceObject(context: WKInterfaceObjectRepresentableContext<MapView>) -> WKInterfaceMap {
        WKInterfaceMap()
    }

    func updateWKInterfaceObject(_ map: WKInterfaceMap, context: WKInterfaceObjectRepresentableContext<MapView>) {
        if widget.item?.stateAsLocation() != nil {
            map.addAnnotation(widget.coordinate, with: WKInterfaceMapPinColor.red)

            let region = MKCoordinateRegion(center: widget.coordinate,
                                            latitudinalMeters: 1000.0,
                                            longitudinalMeters: 1000.0)
            map.setRegion(region)
        }
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[9]
        return MapView(widget: widget)
    }
}
