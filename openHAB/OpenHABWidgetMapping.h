//
//  OpenHABWidgetMapping.h
//  openHAB
//
//  Created by Victor Belov on 17/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "NSObject+Data.h"
#import <Foundation/Foundation.h>

@class GDataXMLElement;

@interface OpenHABWidgetMapping : NSObject
{
    NSString *command;
    NSString *label;
}

@property (nonatomic, retain) NSString *command;
@property (nonatomic, retain) NSString *label;

- (OpenHABWidgetMapping *) initWithXML:(GDataXMLElement *)xmlElement;
- (OpenHABWidgetMapping *) initWithDictionary:(NSDictionary *)dictionary;

@end
