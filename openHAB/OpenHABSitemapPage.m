//
//  OpenHABSitemapPage.m
//  HelloRestKit
//
//  Created by Victor Belov on 10/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "OpenHABSitemapPage.h"
#import "GDataXMLNode.h"
#import "OpenHABWidget.h"

@implementation OpenHABSitemapPage
@synthesize widgets, pageId, title, link;

- (OpenHABSitemapPage *) initWithXML:(GDataXMLElement *)xmlElement
{
    self = [super init];
    widgets = [[NSMutableArray alloc] init];
    for (GDataXMLElement *child in [xmlElement children]) {
        if (![[child name] isEqual:@"widget"]) {
            if (![[child name] isEqual:@"id"]) {
                if ([[self allPropertyNames] containsObject:[child name]])
                    [self setValue:[child stringValue] forKey:[child name]];
            } else {
                pageId = [child stringValue];
            }
        } else {
            OpenHABWidget *newWidget = [[OpenHABWidget alloc] initWithXML:child];
            if (newWidget != nil)
                [widgets addObject:newWidget];
            // If widget have child widgets, cycle through them too
            if ([child elementsForName:@"widget"] > 0) {
                for (GDataXMLElement *childChild in [child elementsForName:@"widget"]) {
                    if ([[child name] isEqual:@"widget"]) {
                        OpenHABWidget *newChildWidget =[[OpenHABWidget alloc] initWithXML:childChild];
                        if (newChildWidget != nil)
                            [widgets addObject:newChildWidget];
                    }
                }
            }
        }
    }
    return self;
}

@end
