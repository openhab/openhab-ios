// Copyright (c) 2010-2021 Contributors to the openHAB project
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

class MapViewTableViewCell: GenericUITableViewCell {
    private var mapView: MKMapView!

    override var widget: OpenHABWidget! {
        get {
            super.widget
        }
        set(widget) {
            let oldLocationCoordinate: CLLocationCoordinate2D? = self.widget?.coordinate
            let oldLocationTitle = self.widget?.labelText ?? ""
            let newLocationCoordinate: CLLocationCoordinate2D? = widget?.coordinate
            let newLocationTitle = widget?.labelText

            super.widget = widget

            if !(oldLocationCoordinate?.latitude == newLocationCoordinate?.latitude && oldLocationCoordinate?.longitude == newLocationCoordinate?.longitude && (oldLocationTitle == newLocationTitle)) {
                mapView.removeAnnotations(mapView.annotations)

                if widget?.item?.stateAsLocation() != nil {
                    if let widget = widget {
                        mapView.addAnnotation(widget)
                    }
                    mapView.setRegion(MKCoordinateRegion(center: (widget?.coordinate)!, latitudinalMeters: 1000.0, longitudinalMeters: 1000.0), animated: false)
                }
            }
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        mapView = MKMapView(frame: CGRect.zero)
        mapView.layer.cornerRadius = 4.0
        mapView.layer.masksToBounds = true
        contentView.addSubview(mapView)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        mapView = MKMapView(frame: CGRect.zero)
        mapView.layer.cornerRadius = 4.0
        mapView.layer.masksToBounds = true
        contentView.addSubview(mapView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        mapView.frame = contentView.bounds.insetBy(dx: 13.0, dy: 8.0)
    }
}
