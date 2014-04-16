//
//  OpenHABAppDataDelegate.h
//  openHAB
//
//  Created by Victor Belov on 14/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import <Foundation/Foundation.h>
@class OpenHABDataObject;

@protocol OpenHABAppDataDelegate <NSObject>

- (OpenHABDataObject*) appData;

@end
