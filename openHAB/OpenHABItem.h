//
//  OpenHABItem.h
//  HelloRestKit
//
//  Created by Victor Belov on 10/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "NSObject+Data.h"
#import <Foundation/Foundation.h>
@class GDataXMLElement;

@interface OpenHABItem : NSObject
{
    NSString *type;
    NSString *name;
    NSString *state;
    NSString *link;
}

@property (nonatomic, retain) NSString *type;
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *state;
@property (nonatomic, retain) NSString *link;

- (OpenHABItem *) initWithXML:(GDataXMLElement *)xmlElement;

@end
