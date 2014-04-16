//
//  OpenHABTracker.h
//  openHAB
//
//  Created by Victor Belov on 13/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Reachability+URL.h"

@protocol OpenHABTrackerDelegate <NSObject>
- (void)openHABTracked:(NSString *)openHABUrl;
@optional
- (void)openHABTrackingProgress:(NSString *)message;
- (void)openHABTrackingError:(NSError *)error;
- (void)openHABTrackingNetworkChange:(NetworkStatus)networkStatus;
@end

@interface OpenHABTracker : NSObject <NSNetServiceDelegate, NSNetServiceBrowserDelegate> {
    NSString *openHABLocalUrl;
    NSString *openHABRemoteUrl;
    BOOL openHABDemoMode;
    NSNetService *netService;
    Reachability *reach;
    NetworkStatus oldReachabilityStatus;
}

@property (nonatomic, weak) id<OpenHABTrackerDelegate> delegate;
@property (nonatomic, assign) BOOL  openHABDemoMode;
@property (nonatomic, retain) NSString *openHABLocalUrl;
@property (nonatomic, retain) NSString *openHABRemoteUrl;
@property (nonatomic, copy) NSNetService *netService;
@property (nonatomic, retain) Reachability *reach;

- (void)startTracker;
// NSNetService delegate methods for publication
- (void)netServiceDidResolveAddress:(NSNetService *)netService;
- (void)netService:(NSNetService *)netService
     didNotResolve:(NSDictionary *)errorDict;

@end
