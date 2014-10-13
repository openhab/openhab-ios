//
//  OpenHABTracker.m
//  openHAB
//
//  Created by Victor Belov on 13/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "OpenHABTracker.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <SystemConfiguration/SCNetworkReachability.h>
#import "Reachability+URL.h"
#import <FastSocket.h>

@implementation OpenHABTracker
@synthesize openHABDemoMode, openHABLocalUrl, openHABRemoteUrl, delegate, netService, reach;

- (OpenHABTracker *)init
{
    self = [super init];
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    openHABDemoMode = [prefs boolForKey:@"demomode"];
    openHABLocalUrl = [prefs valueForKey:@"localUrl"];
    openHABRemoteUrl = [prefs valueForKey:@"remoteUrl"];
    return self;
}

- (void)startTracker
{
    // Check if any network is available
    if ([self isNetworkConnected]) {
        // Check if demo mode is switched on in preferences
        if (self.openHABDemoMode) {
            NSLog(@"OpenHABTracker demo mode preference is on");
            [self trackedDemoMode];
        } else {
            // Check if network is WiFi. If not, go for remote URL
            if (![self isNetworkWiFi]) {
                NSLog(@"OpenHABTracker network is not WiFi");
                [self trackedRemoteUrl];
            // If it is WiFi
            } else {
                NSLog(@"OpenHABTracker network is Wifi");
                // Check if local URL is configured, if yes
                if ([openHABLocalUrl length] > 0) {
                    if ([self isURLReachable:[NSURL URLWithString:openHABLocalUrl]]) {
                        [self trackedLocalUrl];
                    } else {
                        [self trackedRemoteUrl];
                    }
                // If not, go for Bonjour discovery
                } else {
                    [self startDiscovery];
                }
            }
        }
    } else {
        if (self.delegate && [self.delegate respondsToSelector:@selector(openHABTrackingError:)]) {
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:@"Network is not available." forKey:NSLocalizedDescriptionKey];
            NSError *trackingError = [NSError errorWithDomain:@"openHAB" code:100 userInfo:errorDetail];
            [self.delegate openHABTrackingError:trackingError];
            self.reach = [Reachability reachabilityForInternetConnection];
            oldReachabilityStatus = [reach currentReachabilityStatus];
            [[NSNotificationCenter defaultCenter] addObserver: self
                                                     selector: @selector(reachabilityChanged:)
                                                         name: kReachabilityChangedNotification
                                                       object: nil];
            [self.reach startNotifier];
        }
    }
}

- (void)trackedLocalUrl
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(openHABTrackingProgress:)]) {
        [self.delegate openHABTrackingProgress:@"Connecting to local URL"];
    }
    NSString *openHABUrl = [self normalizeUrl:openHABLocalUrl];
    [self trackedUrl:openHABUrl];
}

- (void)trackedRemoteUrl
{
    NSString *openHABUrl = [self normalizeUrl:openHABRemoteUrl];
    if ([openHABUrl length] > 0) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(openHABTrackingProgress:)]) {
            [self.delegate openHABTrackingProgress:@"Connecting to remote URL"];
        }
        [self trackedUrl:openHABUrl];
    } else {
        if (self.delegate && [self.delegate respondsToSelector:@selector(openHABTrackingError:)]) {
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:@"Remote URL is not configured." forKey:NSLocalizedDescriptionKey];
            NSError *trackingError = [NSError errorWithDomain:@"openHAB" code:101 userInfo:errorDetail];
            [self.delegate openHABTrackingError:trackingError];
        }
    }
}

- (void)trackedDiscoveryUrl:(NSString *)discoveryUrl
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(openHABTrackingProgress:)]) {
        [self.delegate openHABTrackingProgress:@"Connecting to discovered URL"];
    }
    [self trackedUrl:discoveryUrl];
}

- (void)trackedDemoMode
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(openHABTrackingProgress:)]) {
        [self.delegate openHABTrackingProgress:@"Running in demo mode. Check settings to disable demo mode."];
    }
    [self trackedUrl:@"http://demo.openhab.org:8080"];
}

- (void)trackedUrl:(NSString *)trackedUrl
{
    if (self.delegate)
        [self.delegate openHABTracked:trackedUrl];
}

- (void) reachabilityChanged: (NSNotification *)notification {
    Reachability *changedReach = [notification object];
    if( [changedReach isKindOfClass: [Reachability class]]) {
        NetworkStatus nStatus = [changedReach currentReachabilityStatus];
        if (nStatus != oldReachabilityStatus) {
            NSLog(@"Network status changed from %@ to %@", [self stringFromStatus:oldReachabilityStatus], [self stringFromStatus:nStatus]);
            oldReachabilityStatus = nStatus;
            if (self.delegate && [self.delegate respondsToSelector:@selector(openHABTrackingNetworkChange:)]) {
                [self.delegate openHABTrackingNetworkChange:nStatus];
            }
        }
    }
}

- (void)startDiscovery
{
    NSLog(@"OpenHABTracking starting Bonjour discovery");
    if (self.delegate && [self.delegate respondsToSelector:@selector(openHABTrackingProgress:)]) {
        [self.delegate openHABTrackingProgress:@"Discovering openHAB"];
    }
    netService = [[NSNetService alloc] initWithDomain:@"local." type:@"_openhab-server-ssl._tcp." name:@"openHAB-ssl"];
    [netService setDelegate:self];
    [netService resolveWithTimeout:5.0];
}

// NSNetService delegate methods for Bonjour resolving
- (void)netServiceDidResolveAddress:(NSNetService *)resolvedNetService
{
    NSLog(@"OpenHABTracker discovered %@:%@", [self getStringIpFromAddressData:resolvedNetService.addresses[0]], [self getStringPortFromAddressData:resolvedNetService.addresses[0]]);
    NSString *openhabUrl = [NSString stringWithFormat:@"https://%@:%@", [self getStringIpFromAddressData:resolvedNetService.addresses[0]], [self getStringPortFromAddressData:resolvedNetService.addresses[0]]];
    [self trackedDiscoveryUrl:openhabUrl];
}

- (void)netService:(NSNetService *)netService
     didNotResolve:(NSDictionary *)errorDict
{
    NSLog(@"OpenHABTracker discovery didn't resolve openHAB");
    [self trackedRemoteUrl];
}

- (NSString *)normalizeUrl:(NSString *)url
{
    if ([url hasSuffix:@"/"]) {
        url = [url substringToIndex:url.length - 1];
    }
    return url;
}

- (BOOL) validateUrl: (NSString *) url {
    NSString *theURL =
    @"(http|https)://((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+";
    NSPredicate *urlTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", theURL];
    return [urlTest evaluateWithObject:url];
}

- (BOOL)isNetworkConnected
{
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    SCNetworkReachabilityRef defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&zeroAddress);
    SCNetworkReachabilityFlags flags;
    BOOL didRetrieveFlags = SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags);
    CFRelease(defaultRouteReachability);
    if (!didRetrieveFlags)
    {
        return NO;
    }
    BOOL isReachable = flags & kSCNetworkFlagsReachable;
    BOOL needsConnection = flags & kSCNetworkFlagsConnectionRequired;
    return (isReachable && !needsConnection) ? YES : NO;
}

- (BOOL)isNetworkConnected2
{
    Reachability *networkReach = [Reachability reachabilityForInternetConnection];
    NetworkStatus networkReachabilityStatus = [networkReach currentReachabilityStatus];
    NSLog(@"Network status = %d", networkReachabilityStatus);
    if (networkReachabilityStatus == ReachableViaWiFi || networkReachabilityStatus == ReachableViaWWAN) {
        return YES;
    }
    return NO;
}

- (BOOL)isNetworkWiFi
{
    Reachability *wifiReach = [Reachability reachabilityForInternetConnection];
    NetworkStatus wifiReachabilityStatus = [wifiReach currentReachabilityStatus];
    if (wifiReachabilityStatus == ReachableViaWiFi) {
        return YES;
    }
    return NO;
}

- (NSString *)getStringIpFromAddressData:(NSData *)dataIn {
    struct sockaddr_in  *socketAddress = nil;
    NSString            *ipString = nil;
    
    socketAddress = (struct sockaddr_in *)[dataIn bytes];
    ipString = [NSString stringWithFormat: @"%s",
                inet_ntoa(socketAddress->sin_addr)];  ///problem here
    return ipString;
}

- (NSString *)getStringPortFromAddressData:(NSData *)dataIn {
    struct sockaddr_in  *socketAddress = nil;
    NSString            *ipPort = nil;
    
    socketAddress = (struct sockaddr_in *)[dataIn bytes];
    ipPort = [NSString stringWithFormat: @"%hu",
              ntohs(socketAddress->sin_port)];  ///problem here
    return ipPort;
}

- (BOOL)isURLReachable:(NSURL*) url
{
    FastSocket *client = [[FastSocket alloc] initWithHost:[url host] andPort:[[url port] stringValue]];
    NSLog(@"Checking if %@:%@ is reachable", [url host], [[url port] stringValue]);
    if ([client connect:1]) {
        [client close];
        return YES;
    }
    return NO;
}

- (NSString *)stringFromStatus:(NetworkStatus) status {
    
    NSString *string;
    switch(status) {
        case NotReachable:
            string = @"unreachable";
            break;
        case ReachableViaWiFi:
            string = @"WiFi";
            break;
        case ReachableViaWWAN:
            string = @"WWAN";
            break;
        default:
            string = @"Unknown";
            break;
    }
    return string;
}

@end
