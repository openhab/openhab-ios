//
//  MapViewTableViewCell.swift
//  openHAB
//
//  Created by Manfred Scheiner on 12.09.18.
//  Copyright © 2018 openHAB e.V. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import MapKit

class MapViewTableViewCell: GenericUITableViewCell {
    private var mapView: MKMapView!

    override var widget: OpenHABWidget! {
        get {
            return super.widget
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
