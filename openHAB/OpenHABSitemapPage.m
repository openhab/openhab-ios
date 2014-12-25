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
@synthesize widgets, pageId, title, link, leaf, delegate;

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
            if (newWidget != nil) {
                [newWidget setDelegate:self];
                [widgets addObject:newWidget];
            }
            // If widget have child widgets, cycle through them too
            if ([child elementsForName:@"widget"] > 0) {
                for (GDataXMLElement *childChild in [child elementsForName:@"widget"]) {
                    if ([[child name] isEqual:@"widget"]) {
                        OpenHABWidget *newChildWidget =[[OpenHABWidget alloc] initWithXML:childChild];
                        if (newChildWidget != nil) {
                            [newChildWidget setDelegate:self];
                            [widgets addObject:newChildWidget];
                        }
                    }
                }
            }
        }
    }
    return self;
}

- (OpenHABSitemapPage *) initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    widgets = [[NSMutableArray alloc] init];
    pageId = [dictionary valueForKey:@"id"];
    title = [dictionary valueForKey:@"title"];
    link = [dictionary valueForKey:@"link"];
    leaf = [dictionary valueForKey:@"leaf"];
    NSArray *widgetsArray = [dictionary objectForKey:@"widgets"];
    for (NSDictionary *widgetDictionary in widgetsArray) {
        OpenHABWidget *newWidget = [[OpenHABWidget alloc] initWithDictionary:widgetDictionary];
        if (newWidget != nil) {
            [newWidget setDelegate:self];
            [widgets addObject:newWidget];
        }
        if ([widgetDictionary objectForKey:@"widgets"] != nil) {
            NSArray *childWidgetsArray = [widgetDictionary objectForKey:@"widgets"];
            for (NSDictionary *childWidgetDictionary in childWidgetsArray) {
                OpenHABWidget *newChildWidget = [[OpenHABWidget alloc] initWithDictionary:childWidgetDictionary];
                if (newChildWidget != nil) {
                    [newChildWidget setDelegate:self];
                    [widgets addObject:newChildWidget];
                }
            }
        }
    }
    return self;
}


- (void) sendCommand:(OpenHABItem *)item commandToSend:(NSString *)command
{
    NSLog(@"SitemapPage sending command %@ to %@", command, item.name);
    if (self.delegate != nil)
        [self.delegate sendCommand:item commandToSend:command];
}

@end
