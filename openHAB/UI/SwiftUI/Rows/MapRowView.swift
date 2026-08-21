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

private struct MapContent: View {
    let coordinate: CLLocationCoordinate2D
    let height: CGFloat?

    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
    )

    var body: some View {
        Map(position: $cameraPosition) {
            Marker("", coordinate: coordinate)
        }
        .frame(height: height)
        .clipShape(.rect(cornerRadius: 8))
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

struct MapRowView: View {
    let input: MediaRowInput

    private var coordinate: CLLocationCoordinate2D? {
        guard let latitude = input.coordinateLatitude,
              let longitude = input.coordinateLongitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var body: some View {
        let displayState = input.displayState
        VStack(alignment: .leading, spacing: 8) {
            if !displayState.labelText.isEmpty, input.labelSourceRawValue == OpenHABWidget.LabelSource.sitemapDefinition.rawValue {
                Text(displayState.labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))
            }

            if let coordinate {
                MapContent(coordinate: coordinate, height: input.preferredRowHeight.map { CGFloat($0) })
            }
        }
    }
}

extension CLLocationCoordinate2D: @retroactive Identifiable {
    var id: String {
        "\(latitude),\(longitude)"
    }
}
