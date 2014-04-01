//
//  OpenHABSitemapPage.h
//  HelloRestKit
//
//  Created by Victor Belov on 10/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "NSObject+Data.h"
#import <Foundation/Foundation.h>
@class GDataXMLElement;

@interface OpenHABSitemapPage : NSObject
{
    NSMutableArray *widgets;
    NSString *pageId;
    NSString *title;
    NSString *link;
}
@property (nonatomic, retain) NSArray *widgets;
@property (nonatomic, retain) NSString *pageId;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *link;

- (OpenHABSitemapPage *) initWithXML:(GDataXMLElement *)xmlElement;

@end
