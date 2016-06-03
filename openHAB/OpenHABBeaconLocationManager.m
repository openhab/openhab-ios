//
//  OpenHABBeaconLocationManager.m
//  openHAB
//
//  Created by Uwe on 03.06.16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//

#import "OpenHABBeaconLocationManager.h"
#import "OpenHABBeaconNotification.h"
#import "OpenHABAppDelegate.h"
#import "OpenHABViewController.h"

@implementation OpenHABBeaconLocationManager

- (OpenHABBeaconLocationManager *)init
{
    self = [super init];
    if (self)
    {
        _coreLocation = [[CLLocationManager alloc] init];
        _coreLocation.delegate = self;
        // iOS8+ - Ask for permissions to use location
        if ([_coreLocation respondsToSelector:@selector(requestAlwaysAuthorization)])
        {
            [_coreLocation requestAlwaysAuthorization];
        }
        else
        {
            [self loadBeacons];
        }
    }
    return self;
}


-(void)addBeacon:(OpenHABBeaconNotification*)newBeacon
{
    [_activeBeacons addObject:newBeacon];
    
    CLBeaconRegion* region = [self createBeaconRegion:newBeacon];
    if(region)
    {
        if (newBeacon.localNotification == 1)
        {
            if (newBeacon.onEnterItem != nil)
            {
                region.notifyOnEntry = [NSString stringWithFormat:@"In range: %@-%d-%d",newBeacon.beaconUUID,[newBeacon.beaconMajor intValue], [newBeacon.beaconMinor intValue]];
            }
            if (newBeacon.onLeaveItem != nil)
            {
                region.notifyOnExit = [NSString stringWithFormat:@"Out of range: %@-%d-%d",newBeacon.beaconUUID,[newBeacon.beaconMajor intValue], [newBeacon.beaconMinor intValue]];
            }
        }
        
        [_coreLocation startMonitoringForRegion:region];
    }
    
    [self saveBeacons];
    
}

-(void)removeBeacon:(OpenHABBeaconNotification*)beacon
{
    [_activeBeacons removeObject:beacon];
    CLBeaconRegion* beaconRegion = [self createBeaconRegion:beacon];
    
    if (beaconRegion)
    {
        [_coreLocation stopMonitoringForRegion:beaconRegion];
    }
    
    [self saveBeacons];
}

-(CLBeaconRegion*)createBeaconRegion:(OpenHABBeaconNotification*)newBeacon
{
    CLBeaconRegion *region = nil;
    NSUUID* uuid = [[NSUUID alloc] initWithUUIDString:newBeacon.beaconUUID];
    
    if(uuid && newBeacon.beaconMajor && newBeacon.beaconMinor)
    {
        NSString* identifier = [NSString stringWithFormat:@"es.spaphone.openhab.%@-%d-%d",newBeacon.beaconUUID,[newBeacon.beaconMajor intValue], [newBeacon.beaconMinor intValue]];
        region = [[CLBeaconRegion alloc] initWithProximityUUID:uuid major:[newBeacon.beaconMajor shortValue] minor:[newBeacon.beaconMinor shortValue] identifier:identifier];
    }
    else if(uuid && newBeacon.beaconMajor)
    {
        NSString* identifier = [NSString stringWithFormat:@"es.spaphone.openhab.%@-%d",newBeacon.beaconUUID, [newBeacon.beaconMajor intValue]];
        region = [[CLBeaconRegion alloc] initWithProximityUUID:uuid major:[newBeacon.beaconMajor shortValue]identifier:identifier];
    }
    else if(uuid)
    {
        NSString* identifier = [NSString stringWithFormat:@"es.spaphone.openhab.%@",newBeacon.beaconUUID];
        region = [[CLBeaconRegion alloc] initWithProximityUUID:uuid identifier:identifier];
    }
    
    return region;
}

#pragma mark Persistence
-(void)saveBeacons
{
    NSString* documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* path = [NSString stringWithFormat:@"%@/beacons.dat", documentsDirectory];
    
    [NSKeyedArchiver archiveRootObject:_activeBeacons toFile:path];
}

-(void)loadBeacons
{
    NSString* documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* path = [NSString stringWithFormat:@"%@/beacons.dat", documentsDirectory];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        _activeBeacons = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        if (_activeBeacons)
        {
            for (OpenHABBeaconNotification* beacon in _activeBeacons)
            {
                CLBeaconRegion* beaconRegion = [self createBeaconRegion:beacon];
                [_coreLocation requestStateForRegion:beaconRegion];
            }
        }
        else
        {
            _activeBeacons = [NSMutableArray array];
        }
    }
    else
    {
        _activeBeacons = [NSMutableArray array];
    }
}

#pragma mark CoreLocation Delegate

-(BOOL)NSNumberEqual:(NSNumber*)number1 toNSNumber:(NSNumber*)number2
{
    if (number1 == nil && number2 == nil)
        return YES;
    if ((number1 == nil && number2 != nil) || (number1 != nil && number2 == nil))
        return NO;
    
    return [number1 isEqualToNumber:number2];
}


-(void)sendNotificationsForRegion:(CLBeaconRegion*)beaconRegion inState:(CLRegionState)state
{
    for (OpenHABBeaconNotification* beacon in _activeBeacons)
    {
        NSString* uuidString = [beaconRegion.proximityUUID UUIDString];
        
        if ([beacon.beaconUUID isEqualToString:uuidString]
            && [self NSNumberEqual:beacon.beaconMajor toNSNumber:beaconRegion.major]
            && [self NSNumberEqual:beacon.beaconMinor toNSNumber:beaconRegion.minor])
        {
            UILocalNotification* notification = [[UILocalNotification alloc] init];
            notification.soundName = UILocalNotificationDefaultSoundName;
            
            if (state == CLRegionStateInside && beacon.lastState != CLRegionStateInside)
            {
                //Do we have an onEnterItem
                if (beacon.onEnterItem)
                {
                    // Send message to the user
                    if (beacon.localNotification == 1)
                    {
                        if (beacon.beaconDescription.length)
                        {
                            notification.alertBody = [NSString stringWithFormat:@"In range: %@",beacon.beaconDescription];
                        }
                        else
                        {
                            notification.alertBody = [NSString stringWithFormat:@"In range: %@-%d-%d",beacon.beaconUUID,[beacon.beaconMajor intValue], [beacon.beaconMinor intValue]];
                        }
                        [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
                    }
                    [[self appData].rootViewController sendCommand:beacon.onEnterItem commandToSend:@"ON"];
                }
            }
            else if (state == CLRegionStateOutside && beacon.lastState != CLRegionStateOutside)
            {
                //Do we have an onLeaveItem
                if (beacon.onLeaveItem)
                {
                    // Send message to the user
                    if (beacon.localNotification == 1)
                    {
                        if (beacon.beaconDescription.length)
                        {
                            notification.alertBody = [NSString stringWithFormat:@"Out of range: %@",beacon.beaconDescription];
                        }
                        else
                        {
                            notification.alertBody = [NSString stringWithFormat:@"Out of range: %@-%d-%d",beacon.beaconUUID,[beacon.beaconMajor intValue], [beacon.beaconMinor intValue]];
                        }
                        [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
                    }
                    [[self appData].rootViewController sendCommand:beacon.onEnterItem commandToSend:@"OFF"];
                    
                }
            }
            beacon.lastState = state;
        }
    }
    
    
}


-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status == kCLAuthorizationStatusAuthorizedAlways)
    {
        [self loadBeacons];
    }
    
}

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region
{
    [self sendNotificationsForRegion:(CLBeaconRegion*)region inState:state];
}

- (OpenHABDataObject*)appData
{
    id<OpenHABAppDataDelegate> theDelegate = (id<OpenHABAppDataDelegate>) [UIApplication sharedApplication].delegate;
    return [theDelegate appData];
}

@end
