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

import CommonUI
import CoreLocation
import MapKit
import OpenHABCore
import SwiftUI

private struct MapRowConfig {
    let input: MediaRowInput
}

@MainActor
private func makeMapRowContent(_ config: MapRowConfig) -> MapRowContent {
    MapRowContent(input: config.input)
}

private struct MapRowContent: View {
    let input: MediaRowInput

    private var coordinate: CLLocationCoordinate2D? {
        guard let latitude = input.coordinateLatitude,
              let longitude = input.coordinateLongitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var body: some View {
        MapRowViewNew(input: input, coordinate: coordinate)
    }
}

private struct MapRowViewNew: View {
    let input: MediaRowInput
    let coordinate: CLLocationCoordinate2D?
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
    )

    var body: some View {
        VStack {
            if let coordinate {
                Map(position: $cameraPosition) {
                    Marker("", coordinate: coordinate)
                }
                .frame(height: input.preferredRowHeight.map { CGFloat($0) })
                .onAppear {
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: coordinate,
                            latitudinalMeters: 1000,
                            longitudinalMeters: 1000
                        )
                    )
                }
            }
        }
    }
}

struct MapRowView: View {
    let input: MediaRowInput

    var body: some View {
        makeMapRowContent(
            MapRowConfig(
                input: input
            )
        )
    }
}

extension CLLocationCoordinate2D: @retroactive Identifiable {
    var id: String {
        "\(latitude),\(longitude)"
    }
}
