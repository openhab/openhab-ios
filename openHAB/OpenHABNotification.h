//
//  OpenHABNotification.h
//  openHAB
//
//  Created by Victor Belov on 25/05/16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//

#import "NSObject+Data.h"
#import <Foundation/Foundation.h>

@interface OpenHABNotification : NSObject

@property (nonatomic, retain) NSString *message;
@property (nonatomic, retain) NSDate *created;
@property (nonatomic, retain) NSString *icon;
@property (nonatomic, retain) NSString *severity;

- (OpenHABNotification *) initWithDictionary:(NSDictionary *)dictionary;

@end
