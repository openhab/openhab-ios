//
//  OpenHABAppDelegate.h
//  openHAB
//
//  Created by Victor Belov on 12/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OpenHABAppDataDelegate.h"

@class OpenHABDataObject;

@interface OpenHABAppDelegate : UIResponder <UIApplicationDelegate, OpenHABAppDataDelegate>
{
    OpenHABDataObject* appData;
}
@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, retain) OpenHABDataObject* appData;

@end
