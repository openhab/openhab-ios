//
//  OpenHABWidget.h
//  HelloRestKit
//
//  Created by Victor Belov on 08/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "NSObject+Data.h"
#import <Foundation/Foundation.h>
@class GDataXMLElement;
@class OpenHABItem;
@class OpenHABLinkedPage;

@protocol OpenHABWidgetDelegate <NSObject>
- (void)sendCommand:(OpenHABItem *)item commandToSend:(NSString *)command;
@end

@interface OpenHABWidget : NSObject
{
    NSString *widgetId;
    NSString *label;
    NSString *icon;
    NSString *type;
    NSString *url;
    NSString *period;
    NSString *minValue;
    NSString *maxValue;
    NSString *step;
    NSString *refresh;
    NSString *height;
    NSString *isLeaf;
    NSString *iconColor;
    NSString *labelcolor;
    NSString *valuecolor;
    NSString *service;
    NSString *state;
    OpenHABItem *item;
    OpenHABLinkedPage *linkedPage;
    NSString *text;
    NSMutableArray *mappings;
}

@property (nonatomic, weak) id<OpenHABWidgetDelegate> delegate;
@property (nonatomic, retain) NSString *widgetId;
@property (nonatomic, retain) NSString *label;
@property (nonatomic, retain) NSString *icon;
@property (nonatomic, retain) NSString *type;
@property (nonatomic, retain) NSString *url;
@property (nonatomic, retain) NSString *period;
@property (nonatomic, retain) NSString *minValue;
@property (nonatomic, retain) NSString *maxValue;
@property (nonatomic, retain) NSString *step;
@property (nonatomic, retain) NSString *refresh;
@property (nonatomic, retain) NSString *height;
@property (nonatomic, retain) NSString *isLeaf;
@property (nonatomic, retain) NSString *iconColor;
@property (nonatomic, retain) NSString *labelcolor;
@property (nonatomic, retain) NSString *valuecolor;
@property (nonatomic, retain) NSString *service;
@property (nonatomic, retain) NSString *state;
@property (nonatomic, retain) OpenHABItem *item;
@property (nonatomic, retain) OpenHABLinkedPage *linkedPage;
@property (nonatomic, retain) NSString *text;
@property (nonatomic, retain) NSMutableArray *mappings;
@property (nonatomic, retain) UIImage *image;

- (OpenHABWidget *) initWithXML:(GDataXMLElement *)xmlElement;
- (OpenHABWidget *) initWithDictionary:(NSDictionary *)dictionary;
- (NSString *) labelText;
- (NSString *) labelValue;
- (void) sendCommand:(NSString *)command;
- (NSUInteger) mappingIndexByCommand:(NSString *)command;

@end
