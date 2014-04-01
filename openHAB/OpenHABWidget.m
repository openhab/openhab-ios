//
//  OpenHABWidget.m
//  HelloRestKit
//
//  Created by Victor Belov on 08/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "OpenHABWidget.h"
#import "OpenHABItem.h"
#import "OpenHABLinkedPage.h"
#import "GDataXMLNode.h"

@implementation OpenHABWidget
@synthesize widgetId, label, icon, type, url, period, minValue, maxValue, step, refresh, height, isLeaf, iconColor, labelColor, valueColor, item, linkedPage, text;

- (OpenHABWidget *) initWithXML:(GDataXMLElement *)xmlElement
{
    self = [super init];
    for (GDataXMLElement *child in [xmlElement children]) {
        if (![[child name] isEqual:@"widget"]) {
            if ([[child name] isEqual:@"item"]) {
                item = [[OpenHABItem alloc] initWithXML:child];
            } else if ([[child name] isEqual:@"linkedPage"]) {
                linkedPage = [[OpenHABLinkedPage alloc] initWithXML:child];
            } else {
                if ([[self allPropertyNames] containsObject:[child name]])
                    [self setValue:[child stringValue] forKey:[child name]];
            }
        }
    }
    return self;
}

@end
