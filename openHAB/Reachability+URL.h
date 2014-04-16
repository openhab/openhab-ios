//
//  Reachability+URL.h
//  openHAB
//
//  Created by Victor Belov on 13/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "Reachability.h"

@interface Reachability (URL)

+ (instancetype)reachabilityWithUrlString:(NSString *)urlString;
+ (instancetype)reachabilityWithUrl:(NSURL *)url;
- (BOOL)currentlyReachable;

@end
