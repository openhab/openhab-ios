//  Converted to Swift 4 by Swiftify v4.2.28993 - https://objectivec2swift.com/
//
//  MapViewTableViewCell.swift
//  openHAB
//
//  Created by Manfred Scheiner on 12.09.18.
//  Copyright © 2018 openHAB e.V. All rights reserved.
//

import MapKit

class MapViewTableViewCell: GenericUITableViewCell {
    private var mapView: MKMapView!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        mapView = MKMapView(frame: CGRect.zero)
        mapView.layer.cornerRadius = 4.0
        mapView.layer.masksToBounds = true
        contentView.addSubview(mapView)
    
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        mapView.frame = contentView.bounds.insetBy(dx: 13.0, dy: 8.0)
    }

    func setWidget(_ widget: OpenHABWidget?) {
        let oldLocationCoordinate: CLLocationCoordinate2D = self.widget.coordinate
        let oldLocationTitle = self.widget.title
        let newLocationCoordinate: CLLocationCoordinate2D? = widget?.coordinate
        let newLocationTitle = widget?.title

        super.widget = widget

        if !(oldLocationCoordinate.latitude == newLocationCoordinate?.latitude && oldLocationCoordinate.longitude == newLocationCoordinate?.longitude && (oldLocationTitle == newLocationTitle)) {
            mapView.removeAnnotations(mapView.annotations)

            if widget?.item.stateAsLocation() != nil {
                if let widget = widget {
                    mapView.addAnnotation(widget)
                }
                mapView.setRegion(MKCoordinateRegion(center: (widget?.coordinate)!, latitudinalMeters: 1000.0, longitudinalMeters: 1000.0), animated: false)
            }
        }
    }
}
