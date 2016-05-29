//
//  OpenHABNotification.m
//  openHAB
//
//  Created by Victor Belov on 25/05/16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//

#import "OpenHABNotification.h"

@implementation OpenHABNotification

- (OpenHABNotification *) initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    NSArray *keyArray =  [dictionary allKeys];
    for (NSString *key in keyArray) {
        if ([key isEqualToString:@"created"]) {
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            // 2015-09-15T13:39:19.938Z
            [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.S'Z'"];
            self.created = [dateFormatter dateFromString: [dictionary objectForKey:key]];
        } else if ([[self allPropertyNames] containsObject:key]) {
            [self setValue:[dictionary objectForKey:key] forKey:key];
        }
    }
    return self;
}

@end
