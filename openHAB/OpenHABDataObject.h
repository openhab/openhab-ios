//
//  OpenHABDataObject.h
//  openHAB
//
//  Created by Victor Belov on 14/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class OpenHABViewController;

@interface OpenHABDataObject : NSObject
{
    NSString* openHABRootUrl;
    NSMutableArray* sitemaps;
    NSString* openHABUsername;
    NSString* openHABPassword;
    OpenHABViewController* rootViewController;
}

@property (nonatomic, copy) NSString* openHABRootUrl;
@property (nonatomic, copy) NSMutableArray* sitemaps;
@property (nonatomic, copy) NSString* openHABUsername;
@property (nonatomic, copy) NSString* openHABPassword;
@property (nonatomic, retain) OpenHABViewController* rootViewController;
@property (nonatomic) int openHABVersion;

@end
