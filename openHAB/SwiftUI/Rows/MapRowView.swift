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

struct MapRowViewLegacy: View {
    @ObservedObject var widget: OpenHABWidget
    private var displayState: WidgetDisplayState { widget.displayState }

    private var region: MKCoordinateRegion {
        let coordinate = CLLocationCoordinate2DIsValid(widget.coordinate) ? widget.coordinate : CLLocationCoordinate2D(latitude: 0, longitude: 0)
        return MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 1000.0,
            longitudinalMeters: 1000.0
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !displayState.labelText.isEmpty, widget.labelSource == .sitemapDefinition {
                let labelText = displayState.labelText
                Text(labelText)
                    .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
                    .lineLimit(1)
            }

            Map(coordinateRegion: .constant(region), annotationItems: CLLocationCoordinate2DIsValid(widget.coordinate) ? [widget.coordinate] : []) { location in
                MapMarker(coordinate: location, tint: .red)
            }
            .frame(height: widget.preferredRowHeight)
            .clipShape(.rect(cornerRadius: 8))
        }
    }
}

@available(iOS 17.0, *)
private struct MapRowViewNew: View {
    @ObservedObject var widget: OpenHABWidget
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
    )
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        VStack {
            if CLLocationCoordinate2DIsValid(widget.coordinate) {
                Map(position: $cameraPosition) {
                    Marker("", coordinate: widget.coordinate)
                }
                .frame(height: widget.preferredRowHeight)
                .onAppear {
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: widget.coordinate,
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
    @ObservedObject var widget: OpenHABWidget

    var body: some View {
        if #available(iOS 17.0, *) {
            MapRowViewNew(widget: widget)
        } else {
            MapRowViewLegacy(widget: widget)
        }
    }
}

extension CLLocationCoordinate2D: @retroactive Identifiable {
    var id: String {
        "\(latitude),\(longitude)"
    }
}
