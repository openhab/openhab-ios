//
//  OpenHABSelectSitemapViewController.m
//  openHAB
//
//  Created by Victor Belov on 14/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "OpenHABSelectSitemapViewController.h"
#import "OpenHABViewController.h"
#import "OpenHABSitemap.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import <SDWebImage/SDWebImageDownloader.h>
#import "OpenHABAppDataDelegate.h"
#import "OpenHABDataObject.h"
#import "AFNetworking.h"
#import "NSMutableURLRequest+Auth.h"
#import "GDataXMLNode.h"
#import "AFRememberingSecurityPolicy.h"

@interface OpenHABSelectSitemapViewController ()

@end

@implementation OpenHABSelectSitemapViewController {
    long selectedSitemap;
}
@synthesize sitemaps, ignoreSSLCertificate;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSLog(@"OpenHABSelectSitemapViewController viewDidLoad");
    if (self.sitemaps != nil) {
        NSLog(@"We have sitemap list here!");
    }
    if ([[self appData] openHABRootUrl] != nil) {
        NSLog(@"OpenHABSelectSitemapViewController openHABRootUrl = %@", [[self appData] openHABRootUrl]);
    }
    self.tableView.tableFooterView = [[UIView alloc] init] ;
    self.sitemaps = [[NSMutableArray alloc] init];
    self.openHABRootUrl = [[self appData] openHABRootUrl];
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    self.openHABUsername = [prefs valueForKey:@"username"];
    self.openHABPassword = [prefs valueForKey:@"password"];
    self.ignoreSSLCertificate = [prefs boolForKey:@"ignoreSSL"];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    NSString *sitemapsUrlString = [NSString stringWithFormat:@"%@/rest/sitemaps", self.openHABRootUrl];
    NSURL *sitemapsUrl = [[NSURL alloc] initWithString:sitemapsUrlString];
    NSMutableURLRequest *sitemapsRequest = [NSMutableURLRequest requestWithURL:sitemapsUrl];
    [sitemapsRequest setAuthCredentials:self.openHABUsername :self.openHABPassword];
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:sitemapsRequest];
    AFRememberingSecurityPolicy *policy = [AFRememberingSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    operation.securityPolicy = policy;
    if (self.ignoreSSLCertificate) {
        NSLog(@"Warning - ignoring invalid certificates");
        operation.securityPolicy.allowInvalidCertificates = YES;
    }
    if ([self appData].openHABVersion == 2) {
        NSLog(@"Setting setializer to JSON");
        operation.responseSerializer = [AFJSONResponseSerializer serializer];
    }
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSData *response = (NSData*)responseObject;
        NSError *error;
        [sitemaps removeAllObjects];
        NSLog(@"Sitemap response");
        // If we are talking to openHAB 1.X, talk XML
        if ([self appData].openHABVersion == 1) {
            NSLog(@"openHAB 1");
            NSLog(@"%@", [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
            GDataXMLDocument *doc = [[GDataXMLDocument alloc] initWithData:response error:&error];
            if (doc == nil) return;
            NSLog(@"%@", [doc.rootElement name]);
            if ([[doc.rootElement name] isEqual:@"sitemaps"]) {
                for (GDataXMLElement *element in [doc.rootElement elementsForName:@"sitemap"]) {
                    OpenHABSitemap *sitemap = [[OpenHABSitemap alloc] initWithXML:element];
                    [sitemaps addObject:sitemap];
                }
            } else {
                return;
            }
        // Newer versions speak JSON!
        } else {
            NSLog(@"openHAB 2");
            if ([responseObject isKindOfClass:[NSArray class]]) {
                NSLog(@"Response is array");
                for (id sitemapJson in responseObject) {
                    OpenHABSitemap *sitemap = [[OpenHABSitemap alloc] initWithDictionaty:sitemapJson];
                    [sitemaps addObject:sitemap];
                }
            } else {
                // Something went wrong, we should have received an array
                return;
            }
        }
        [[self appData] setSitemaps:sitemaps];
        [self.tableView reloadData];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error){
        NSLog(@"Error:------>%@", [error description]);
        NSLog(@"error code %ld",(long)[operation.response statusCode]);
    }];
    [operation start];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [sitemaps count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"SelectSitemapCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    OpenHABSitemap *sitemap = (OpenHABSitemap *)[sitemaps objectAtIndex:indexPath.row];
    if (sitemap.label != nil)
        cell.textLabel.text = sitemap.label;
    else
        cell.textLabel.text = sitemap.name;
    
    NSString * imageBase = [self appData].openHABVersion == 1 ? @"%@/images/%@.png" : @"%@/icon/%@";
    
    if (sitemap.icon != nil) {
        NSString *iconUrlString = [NSString stringWithFormat:imageBase, self.openHABRootUrl, sitemap.icon];
        NSLog(@"icon url = %@", iconUrlString);
        [cell.imageView sd_setImageWithURL:[NSURL URLWithString:iconUrlString] placeholderImage:[UIImage imageNamed:@"blankicon.png"] options:0];
    } else {
        NSString *iconUrlString = [NSString stringWithFormat:imageBase, self.openHABRootUrl,@""];
        [cell.imageView sd_setImageWithURL:[NSURL URLWithString:iconUrlString] placeholderImage:[UIImage imageNamed:@"blankicon.png"] options:0];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"Selected sitemap %ld", (long)indexPath.row);
    OpenHABSitemap *sitemap = [sitemaps objectAtIndex:indexPath.row];
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setValue:sitemap.name forKey:@"defaultSitemap"];
    selectedSitemap = indexPath.row;
    [[self appData] rootViewController].pageUrl = nil;
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
}

- (OpenHABDataObject*)appData
{
    id<OpenHABAppDataDelegate> theDelegate = (id<OpenHABAppDataDelegate>) [UIApplication sharedApplication].delegate;
    return [theDelegate appData];
}


@end
