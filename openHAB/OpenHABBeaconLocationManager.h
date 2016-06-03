//
//  OpenHABBeaconLocationManager.h
//  openHAB
//
//  Created by Uwe on 03.06.16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "OpenHABBeaconNotification.h"

@interface OpenHABBeaconLocationManager : NSObject <CLLocationManagerDelegate>

@property (strong, nonatomic) NSMutableArray* activeBeacons;
@property (strong, nonatomic) CLLocationManager* coreLocation;


-(void)addBeacon:(OpenHABBeaconNotification*)newBeacon;
-(void)removeBeacon:(OpenHABBeaconNotification*)beacon;


@end
