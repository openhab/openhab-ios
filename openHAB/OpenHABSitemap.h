//
//  OpenHABSitemap.h
//  HelloRestKit
//
//  Created by Victor Belov on 10/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "NSObject+Data.h"
#import <Foundation/Foundation.h>
@class GDataXMLElement;

@interface OpenHABSitemap : NSObject
{
    NSString *name;
    NSString *icon;
    NSString *label;
    NSString *link;
    NSString *leaf;
    NSString *homepageLink;
}

@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *icon;
@property (nonatomic, retain) NSString *label;
@property (nonatomic, retain) NSString *link;
@property (nonatomic, retain) NSString *leaf;
@property (nonatomic, retain) NSString *homepageLink;

- (OpenHABSitemap *) initWithXML:(GDataXMLElement *)xmlElement;
- (OpenHABSitemap *) initWithDictionaty:(NSDictionary *)dictionary;

@end
