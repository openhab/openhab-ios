//
//  OpenHABSitemap.m
//  HelloRestKit
//
//  Created by Victor Belov on 10/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  This class parses and holds data for a sitemap list entry
//  REST: /sitemaps
//

#import "OpenHABSitemap.h"
#import "GDataXMLNode.h"

@implementation OpenHABSitemap
@synthesize name, icon, label, link, leaf, homepageLink;

- (OpenHABSitemap *) initWithXML:(GDataXMLElement *)xmlElement
{
    self = [super init];
    for (GDataXMLElement *child in [xmlElement children]) {
        if ([[child name] isEqual:@"homepage"]) {
            for (GDataXMLElement *childChild in [child children]) {
                if ([[childChild name] isEqual:@"link"])
                    homepageLink = [childChild stringValue];
                if ([[childChild name] isEqual:@"leaf"])
                    leaf = [childChild stringValue];
            }
        } else if ([[self allPropertyNames] containsObject:[child name]])
            [self setValue:[child stringValue] forKey:[child name]];
    }
    return self;
}

- (OpenHABSitemap *) initWithDictionaty:(NSDictionary *)dictionary
{
    self = [super init];
    NSArray *keyArray =  [dictionary allKeys];
    for (NSString *key in keyArray) {
        if ([key isEqualToString:@"homepage"]) {
            NSDictionary *homepageDictionary = [dictionary objectForKey:key];
            NSArray *homepageKeyArray = [homepageDictionary allKeys];
            for (NSString *homepageKey in homepageKeyArray) {
                if ([homepageKey isEqualToString:@"link"]) {
                    homepageLink = [homepageDictionary objectForKey:homepageKey];
                }
                if ([homepageKey isEqualToString:@"leaf"]) {
                    leaf = [homepageDictionary objectForKey:homepageKey];
                }
            }
        } else if ([[self allPropertyNames] containsObject:key]) {
            [self setValue:[dictionary objectForKey:key] forKey:key];
        }
    }
    return self;
}

@end
