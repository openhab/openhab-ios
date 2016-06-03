//
//  OpenHABBeaconNotification.m
//  openHAB
//
//  Created by Uwe on 03.06.16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//

#import "OpenHABBeaconNotification.h"

@implementation OpenHABBeaconNotification

#pragma mark Serialization

-(id)init
{
    if (self = [super init])
    {
        _lastState = CLRegionStateUnknown;
    }
    return self;
}

-(id)initWithCoder:(NSCoder*)coder
{
    if (self = [self init])
    {
        _beaconUUID = [coder decodeObjectForKey:@"beaconUUID"];
        _beaconDescription = [coder decodeObjectForKey:@"beaconDescription"];
        _beaconMajor = [coder decodeObjectForKey:@"beaconMajor"];
        _beaconMinor = [coder decodeObjectForKey:@"beaconMinor"];
        _onEnterItem = [coder decodeObjectForKey:@"onEnterItem"];
        _onLeaveItem = [coder decodeObjectForKey:@"onLeaveItem"];
        _lastState = [[coder decodeObjectForKey:@"lastState"] integerValue];
        _localNotification = [[coder decodeObjectForKey:@"localNotification"] integerValue];
    }
    return self;
}

-(void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeObject:_beaconUUID forKey:@"beaconUUID"];
    [coder encodeObject:_beaconDescription forKey:@"beaconDescription"];
    [coder encodeObject:_beaconMajor forKey:@"beaconMajor"];
    [coder encodeObject:_beaconMinor forKey:@"beaconMinor"];
    [coder encodeObject:_onEnterItem forKey:@"onEnterItem"];
    [coder encodeObject:_onLeaveItem forKey:@"onLeaveItem"];
    [coder encodeObject:[NSNumber numberWithInteger:_lastState] forKey:@"lastState"];
    [coder encodeObject:[NSNumber numberWithInteger:_localNotification] forKey:@"localNotification"];
}


@end