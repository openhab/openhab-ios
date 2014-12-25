//
//  OpenHABLinkedPage.m
//  HelloRestKit
//
//  Created by Victor Belov on 10/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "OpenHABLinkedPage.h"
#import "GDataXMLNode.h"

@implementation OpenHABLinkedPage
@synthesize pageId, title, icon, link;

- (OpenHABLinkedPage *) initWithXML:(GDataXMLElement *)xmlElement
{
    self = [super init];
    for (GDataXMLElement *child in [xmlElement children]) {
        if (![[child name] isEqual:@"id"]) {
            if ([[self allPropertyNames] containsObject:[child name]])
                [self setValue:[child stringValue] forKey:[child name]];
        } else {
            pageId = [child stringValue];
        }
    }
    return self;
}

- (OpenHABLinkedPage *) initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    for (NSString *key in [dictionary allKeys]) {
        if (![key isEqualToString:@"id"]) {
            if ([[self allPropertyNames] containsObject:key]) {
                [self setValue:[dictionary objectForKey:key] forKey:key];
            }
        } else {
            pageId = [dictionary objectForKey:key];
        }
    }
    return self;
}

@end
