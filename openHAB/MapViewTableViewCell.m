//
//  MapViewTableViewCell.m
//  openHAB
//
//  Created by Manfred Scheiner on 12.09.18.
//  Copyright © 2018 openHAB e.V. All rights reserved.
//

@import MapKit;
#import "MapViewTableViewCell.h"

@interface MapViewTableViewCell ()

@property (nonatomic, strong, readonly, nonnull) MKMapView *mapView;

@end

@implementation MapViewTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _mapView = [[MKMapView alloc] initWithFrame:CGRectZero];
        _mapView.layer.cornerRadius = 4.0;
        _mapView.layer.masksToBounds = YES;
        [self.contentView addSubview:_mapView];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.mapView.frame = CGRectInset(self.contentView.bounds, 13.0, 8.0);
}

- (void)setWidget:(OpenHABWidget *)widget {
    CLLocationCoordinate2D oldLocationCoordinate = [self.widget coordinate];
    NSString *oldLoactionTitle = [self.widget title];
    CLLocationCoordinate2D newLocationCoordinate = [widget coordinate];
    NSString *newLoactionTitle = [widget title];
    
    [super setWidget:widget];
    
    if (!(oldLocationCoordinate.latitude == newLocationCoordinate.latitude &&
          oldLocationCoordinate.longitude == newLocationCoordinate.longitude &&
          [oldLoactionTitle isEqualToString:newLoactionTitle])) {
        [self.mapView removeAnnotations:self.mapView.annotations];
        
        if ([widget.item stateAsLocation]) {
            [self.mapView addAnnotation:widget];
            [self.mapView setRegion:MKCoordinateRegionMakeWithDistance([widget coordinate], 1000.0, 1000.0) animated:NO];
        }
    }
}

@end
