// Copyright (c) 2010-2025 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import CoreLocation
import MapKit
import OpenHABCore
import SwiftUI

struct WidgetMapView: View {
    @ObservedObject var widget: OpenHABWidget
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    private var coordinates: CLLocationCoordinate2D? {
        guard let state = widget.item?.state, !state.isEmpty else { return nil }
        let components = state.split(separator: ",")
        guard components.count >= 2,
              let latitude = Double(components[0]),
              let longitude = Double(components[1]) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let labelText = widget.labelText, !labelText.isEmpty {
                Text(labelText)
                    .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(UIColor(fromString: widget.labelcolor)))
            }

            Map(coordinateRegion: $region, annotationItems: coordinates.map { [$0] } ?? []) { coordinate in
                MapPin(coordinate: coordinate, tint: .red)
            }
            .frame(height: 200)
            .cornerRadius(8)
            .onAppear {
                if let coordinates {
                    region.center = coordinates
                }
            }

            if let labelValue = widget.labelValue, !labelValue.isEmpty {
                Text(labelValue)
                    .font(.caption)
                    .foregroundColor(widget.valuecolor.isEmpty ? .secondary : Color(UIColor(fromString: widget.valuecolor)))
            }
        }
    }
}

extension CLLocationCoordinate2D: @retroactive Identifiable {
    var id: String {
        "\(latitude),\(longitude)"
    }
}
