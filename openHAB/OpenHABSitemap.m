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

@end
