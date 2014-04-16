//
//  Reachability+URL.m
//  openHAB
//
//  Created by Victor Belov on 13/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "Reachability+URL.h"

@implementation Reachability (URL)

+ (instancetype)reachabilityWithUrlString:(NSString *)urlString
{
    NSURL *url = [NSURL URLWithString:urlString];
    return [self reachabilityWithUrl:url];
}

+ (instancetype)reachabilityWithUrl:(NSURL *)url
{
    return [self reachabilityWithHostName:[url host]];
}

- (BOOL)currentlyReachable
{
    NetworkStatus netStatus = [self currentReachabilityStatus];
    if (netStatus==ReachableViaWiFi || netStatus==ReachableViaWWAN)
        return YES;
    return NO;
}

@end
