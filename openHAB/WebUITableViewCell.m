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

- (void)displayWidget
{
    NSLog(@"webview loading url %@", self.widget.url);
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSString *openHABUsername = [prefs valueForKey:@"username"];
    NSString *openHABPassword = [prefs valueForKey:@"password"];
    NSString *authStr = [NSString stringWithFormat:@"%@:%@", openHABUsername, openHABPassword];
    NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64EncodedStringWithOptions:kNilOptions]];
    NSMutableURLRequest *mutableRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:self.widget.url]];
    [mutableRequest setValue:authValue forHTTPHeaderField:@"Authorization"];
    NSURLRequest *nsrequest=[mutableRequest copy];
    widgetWebView.scrollView.scrollEnabled = NO;
    widgetWebView.scrollView.bounces = NO;
    [widgetWebView loadRequest:nsrequest];
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
