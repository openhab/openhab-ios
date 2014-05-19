//
//  WebUITableViewCell.m
//  openHAB
//
//  Created by Victor Belov on 19/05/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "WebUITableViewCell.h"

@implementation WebUITableViewCell

@synthesize widgetWebView, isLoadingUrl, isLoaded;

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.separatorInset = UIEdgeInsetsZero;
        widgetWebView = (UIWebView*)[self viewWithTag:1001];
    }
    return self;
}

- (void)loadWidget:(OpenHABWidget *)widgetToLoad
{
    self.widget = widgetToLoad;
}

- (void)displayWidget
{
    NSLog(@"webview loading url %@", self.widget.url);
        NSURL *nsurl=[NSURL URLWithString:self.widget.url];
        NSURLRequest *nsrequest=[NSURLRequest requestWithURL:nsurl];
        [widgetWebView loadRequest:nsrequest];
    NSLog(@"webview size %f %f", widgetWebView.frame.size.width, widgetWebView.frame.size.height);
    NSLog(@"scrollview size %f %f", widgetWebView.scrollView.frame.size.width, widgetWebView.scrollView.frame.size.height);
}

-(void)webViewDidStartLoad:(UIWebView *)webView
{
    NSLog(@"webview started loading");
}

-(void)webViewDidFinishLoad:(UIWebView *)webView
{
    NSLog(@"webview finished load");
}

-(void)setFrame:(CGRect)frame
{
    NSLog(@"setFrame");
    [super setFrame:frame];
    [self.widgetWebView reload];
}

@end
