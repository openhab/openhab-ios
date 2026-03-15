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
        if #available(iOS 17.0, *) {
            MapRowViewNew(input: input, coordinate: coordinate)
        } else {
            MapRowViewLegacy(input: input, coordinate: coordinate)
        }
    }
}

struct MapRowViewLegacy: View {
    let input: MediaRowInput
    let coordinate: CLLocationCoordinate2D?

    private var region: MKCoordinateRegion {
        let coordinate = coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        return MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 1000.0,
            longitudinalMeters: 1000.0
        )
    }

    var body: some View {
        let displayState = input.displayState
        VStack(alignment: .leading, spacing: 8) {
            if !displayState.labelText.isEmpty, input.labelSourceRawValue == OpenHABWidget.LabelSource.sitemapDefinition.rawValue {
                let labelText = displayState.labelText
                Text(labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))
            }

            Map(coordinateRegion: .constant(region), annotationItems: coordinate.map { [$0] } ?? []) { location in
                MapMarker(coordinate: location, tint: .red)
            }
            .frame(height: input.preferredRowHeight.map { CGFloat($0) })
            .clipShape(.rect(cornerRadius: 8))
        }
    }
}

@available(iOS 17.0, *)
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
