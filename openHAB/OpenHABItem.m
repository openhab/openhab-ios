//
//  OpenHABItem.m
//  HelloRestKit
//
//  Created by Victor Belov on 10/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "OpenHABItem.h"
#import "GDataXMLNode.h"

@implementation OpenHABItem
@synthesize type, name, state, link;

- (OpenHABItem *) initWithXML:(GDataXMLElement *)xmlElement
{
    self = [super init];
    for (GDataXMLElement *child in [xmlElement children]) {
        if ([[self allPropertyNames] containsObject:[child name]])
            [self setValue:[child stringValue] forKey:[child name]];
    }
    return self;
}

- (OpenHABItem *) initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    for (NSString *key in [dictionary allKeys]) {
        if ([[self allPropertyNames] containsObject:key]) {
            NSLog(@"%@ = %@", key, [dictionary objectForKey:key]);
            [self setValue:[dictionary objectForKey:key] forKey:key];
        }
    }
    return self;
}


- (float) stateAsFloat
{
    return [state floatValue];
}

- (int) stateAsInt
{
    return (int)[state integerValue];
}

- (UIColor*) stateAsUIColor
{
    if ([state isEqualToString:@"Uninitialized"]) {
        return [UIColor colorWithHue:0 saturation:0 brightness:0 alpha:1.0];
    } else {
        NSArray *values = [state componentsSeparatedByString:@","];
        if ([values count] == 3) {
            CGFloat hue = [(NSString*)[values objectAtIndex:0] floatValue]/360;
            CGFloat saturation = [(NSString*)[values objectAtIndex:1] floatValue]/100;
            CGFloat brightness = [(NSString*)[values objectAtIndex:2] floatValue]/100;
            NSLog(@"%f %f %f", hue, saturation, brightness);
            return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1.0];
        } else {
            return [UIColor colorWithHue:0 saturation:0 brightness:0 alpha:1.0];
        }
    }
}

@end
