//
//  OpenHABWidgetMapping.m
//  openHAB
//
//  Created by Victor Belov on 17/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "OpenHABWidgetMapping.h"
#import "GDataXMLNode.h"

@implementation OpenHABWidgetMapping
@synthesize command, label;

- (OpenHABWidgetMapping *) initWithXML:(GDataXMLElement *)xmlElement
{
    self = [super init];
    for (GDataXMLElement *child in [xmlElement children]) {
        if ([[self allPropertyNames] containsObject:[child name]])
            [self setValue:[child stringValue] forKey:[child name]];
    }
    return self;
}

@end
