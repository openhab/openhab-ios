//
//  WebUITableViewCell.h
//  openHAB
//
//  Created by Victor Belov on 19/05/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "GenericUITableViewCell.h"

@interface WebUITableViewCell : GenericUITableViewCell <UIWebViewDelegate>

@property (nonatomic, retain) UIWebView *widgetWebView;
@property (nonatomic) BOOL isLoadingUrl;
@property (nonatomic) BOOL isLoaded;

@end
