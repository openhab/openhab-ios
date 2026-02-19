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
    let widget: OpenHABWidget
}

@MainActor
private func makeMapRowContent(_ config: MapRowConfig) -> MapRowContent {
    MapRowContent(input: config.input, widget: config.widget)
}

private struct MapRowContent: View {
    let input: MediaRowInput
    @ObservedObject var widget: OpenHABWidget

    var body: some View {
        if #available(iOS 17.0, *) {
            MapRowViewNew(widget: widget, input: input)
        } else {
            MapRowViewLegacy(widget: widget, input: input)
        }
    }
}

struct MapRowViewLegacy: View {
    @ObservedObject var widget: OpenHABWidget
    let input: MediaRowInput

    private var region: MKCoordinateRegion {
        let coordinate = CLLocationCoordinate2DIsValid(widget.coordinate) ? widget.coordinate : CLLocationCoordinate2D(latitude: 0, longitude: 0)
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
    let input: MediaRowInput
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
    )

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
        makeMapRowContent(
            MapRowConfig(
                input: MediaRowInput.from(widget: widget),
                widget: widget
            )
        )
    }
}

struct MapRowInputView: View {
    let rowID: RowID
    let input: MediaRowInput
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        if let widget = viewModel.widget(for: rowID) {
            makeMapRowContent(
                MapRowConfig(
                    input: input,
                    widget: widget
                )
            )
        } else {
            EmptyView()
        }
    }
}

extension CLLocationCoordinate2D: @retroactive Identifiable {
    var id: String {
        "\(latitude),\(longitude)"
    }
}
