//
//  OpenHABSitemapPage.h
//  HelloRestKit
//
//  Created by Victor Belov on 10/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "NSObject+Data.h"
#import <Foundation/Foundation.h>
#import "OpenHABWidget.h"
#import "OpenHABItem.h"
@class GDataXMLElement;

@protocol OpenHABSitemapPageDelegate <NSObject>
- (void)sendCommand:(OpenHABItem *)item commandToSend:(NSString *)command;
@end

@interface OpenHABSitemapPage : NSObject <OpenHABWidgetDelegate>
{
    NSMutableArray *widgets;
    NSString *pageId;
    NSString *title;
    NSString *link;
}

@property (nonatomic, weak) id<OpenHABSitemapPageDelegate> delegate;
@property (nonatomic, retain) NSMutableArray *widgets;
@property (nonatomic, retain) NSString *pageId;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *link;
@property (nonatomic, retain) NSString *leaf;

- (OpenHABSitemapPage *) initWithXML:(GDataXMLElement *)xmlElement;
- (OpenHABSitemapPage *) initWithDictionary:(NSDictionary *)dictionary;

@end
