//
//  OpenHABLinkedPage.h
//  HelloRestKit
//
//  Created by Victor Belov on 10/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "NSObject+Data.h"
#import <Foundation/Foundation.h>
@class GDataXMLElement;

@interface OpenHABLinkedPage : NSObject
{
    NSString *pageId;
    NSString *title;
    NSString *icon;
    NSString *link;
}

@property (nonatomic, retain) NSString *pageId;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *icon;
@property (nonatomic, retain) NSString *link;

- (OpenHABLinkedPage *) initWithXML:(GDataXMLElement *)xmlElement;
- (OpenHABLinkedPage *) initWithDictionary:(NSDictionary *)dictionary;

@end
