//
//  OpenHABBeaconNotification.h
//  openHAB
//
//  Created by Uwe on 03.06.16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "OpenHABItem.h"

@interface OpenHABBeaconNotification : NSObject

@property (strong, nonatomic) NSString* beaconUUID;
@property (strong, nonatomic) NSNumber* beaconMajor;
@property (strong, nonatomic) NSNumber* beaconMinor;
@property (strong, nonatomic) NSString* beaconDescription;

@property (strong, nonatomic) OpenHABItem* onEnterItem;
@property (strong, nonatomic) OpenHABItem* onLeaveItem;

@property (assign, nonatomic) NSInteger localNotification;

@property (assign, nonatomic) CLRegionState lastState;


@end