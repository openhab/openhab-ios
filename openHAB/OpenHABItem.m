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

- (float) stateAsFloat
{
    return [state floatValue];
}

- (int) stateAsInt
{
    return [state integerValue];
}

@end
