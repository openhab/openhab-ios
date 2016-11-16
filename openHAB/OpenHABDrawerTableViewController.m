//
//  OpenHABDrawerTableViewController.m
//  openHAB
//
//  Created by Victor Belov on 23/05/16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//

#import "OpenHABDrawerTableViewController.h"
#import "UIViewController+MMDrawerController.h"
#import "OpenHABSettingsViewController.h"
#import "OpenHABSitemap.h"
#import "OpenHABDrawerItem.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import <SDWebImage/SDWebImageDownloader.h>
#import "OpenHABAppDataDelegate.h"
#import "OpenHABDataObject.h"
#import "OpenHABViewController.h"
#import "AFNetworking.h"
#import "NSMutableURLRequest+Auth.h"
#import "GDataXMLNode.h"
#import "OpenHABNotificationsViewControllerTableViewController.h"
#import "DrawerUITableViewCell.h"

@interface OpenHABDrawerTableViewController ()

@end

@implementation OpenHABDrawerTableViewController
@synthesize sitemaps, ignoreSSLCertificate, openHABRootUrl, openHABUsername, openHABPassword, cellCount, drawerItems;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.tableFooterView = [[UIView alloc] init] ;
    self.drawerItems = [NSMutableArray array];
    self.sitemaps = [NSMutableArray array];
    [self loadSettings];
    NSLog(@"OpenHABDrawerTableViewController did load");
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    NSLog(@"OpenHABDrawerTableViewController viewWillAppear");
    NSString *sitemapsUrlString = [NSString stringWithFormat:@"%@/rest/sitemaps", self.openHABRootUrl];
    NSLog(@"Sitemap URL = %@", sitemapsUrlString);
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
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
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
                    [self.sitemaps addObject:sitemap];
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
                    NSLog(@"Sitemap %@", sitemap.label);
                    [self.sitemaps addObject:sitemap];
                }
            } else {
                // Something went wrong, we should have received an array
                return;
            }
        }
        [[self appData] setSitemaps:self.sitemaps];
        [self.tableView reloadData];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error){
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        NSLog(@"Error:------>%@", [error description]);
        NSLog(@"error code %ld",(long)[operation.response statusCode]);
    }];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [operation start];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.drawerItems removeAllObjects];
    // check if we are using my.openHAB, add notifications menu item then
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    if ([[prefs valueForKey:@"remoteUrl"] rangeOfString:@"openhab.org"].location != NSNotFound) {
        OpenHABDrawerItem *notificationsItem = [[OpenHABDrawerItem alloc] init];
        notificationsItem.label = @"Notifications";
        notificationsItem.tag = @"notifications";
        notificationsItem.icon = @"glyphicons-334-bell.png";
        [self.drawerItems addObject:notificationsItem];
    }
    // Settings always go last
    OpenHABDrawerItem *settingsItem = [[OpenHABDrawerItem alloc] init];
    settingsItem.label = @"Settings";
    settingsItem.tag = @"settings";
    settingsItem.icon = @"glyphicons-137-cogwheel.png";
    [self.drawerItems addObject:settingsItem];
//    self.sitemaps = [[self appData] sitemaps];
    [self.tableView reloadData];
    NSLog(@"RightDrawerViewController viewDidAppear");
    NSLog(@"Sitemaps count: %lu", (unsigned long)[self.sitemaps count]);
    NSLog(@"Menu items count: %lu", (unsigned long)[self.drawerItems count]);
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:(BOOL)animated];    // Call the super class implementation.
    NSLog(@"RightDrawerViewController viewDidDisappear");
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Empty first (index 0) row + sitemaps + menu items
    return 1 + [self.sitemaps count] + [self.drawerItems count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DrawerUITableViewCell *cell;
    if ([indexPath row] != 0) {
        static NSString *CellIdentifier = @"DrawerCell";
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
//        if (cell == nil) {
//            cell = [[DrawerUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
//        }
        // First sitemaps
        if ([indexPath row] <= [self.sitemaps count] && [sitemaps count] > 0) {
            cell.textLabel.text = ((OpenHABSitemap *)[sitemaps objectAtIndex:[indexPath row] - 1]).label;
            NSString *iconUrlString = nil;
            if ([self appData].openHABVersion == 2) {
                iconUrlString = [NSString stringWithFormat:@"%@/icon/%@.png", [self appData].openHABRootUrl, ((OpenHABSitemap *)[sitemaps objectAtIndex:[indexPath row] - 1]).icon];
            } else {
                iconUrlString = [NSString stringWithFormat:@"%@/images/%@.png", [self appData].openHABRootUrl, ((OpenHABSitemap *)[sitemaps objectAtIndex:[indexPath row] - 1]).icon];
            }
            NSLog(@"%@", iconUrlString);
            [cell.imageView sd_setImageWithURL:[NSURL URLWithString:iconUrlString] placeholderImage:[UIImage imageNamed:@"icon-76x76.png"] options:0];
        } else {
            // Then menu items
            cell.textLabel.text = ((OpenHABDrawerItem *)[self.drawerItems objectAtIndex:[indexPath row] - [self.sitemaps count] - 1]).label;
            NSString *iconUrlString = nil;
            [cell.imageView sd_setImageWithURL:[NSURL URLWithString:iconUrlString] placeholderImage:[UIImage imageNamed:((OpenHABDrawerItem *)[self.drawerItems objectAtIndex:[indexPath row] - [self.sitemaps count] - 1]).icon] options:0];
        }
        cell.separatorInset = UIEdgeInsetsMake(0, 60, 0, 0);
    } else {
        static NSString *CellIdentifier = @"DrawerHeaderCell";
         cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[DrawerUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        }
    }
    if ([cell respondsToSelector:@selector(setPreservesSuperviewLayoutMargins:)]) {
        [cell setPreservesSuperviewLayoutMargins:NO];
    }
    
    // Explictly set your cell's layout margins
    if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
        [cell setLayoutMargins:UIEdgeInsetsZero];
    }
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([indexPath row] == 0) {
        return 64;
    } else {
        return 44;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // open a alert with an OK and cancel button
    NSLog(@"Clicked on drawer row #%ld", (long)[indexPath row]);
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    if ([indexPath row] != 0) {
        // First sitemaps
        if ([indexPath row] <= [self.sitemaps count] && [sitemaps count] > 0) {
            OpenHABSitemap *sitemap = [self.sitemaps objectAtIndex:indexPath.row - 1];
            NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
            [prefs setValue:sitemap.name forKey:@"defaultSitemap"];
            [[self appData] rootViewController].pageUrl = nil;
            UINavigationController *nav =(UINavigationController *)self.mm_drawerController.centerViewController;
            UIViewController *dummyViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"DummyViewController"];
            [nav pushViewController:dummyViewController animated:NO];
            [nav popToRootViewControllerAnimated:YES];
        } else {
            // Then menu items
            if ([((OpenHABDrawerItem *)[self.drawerItems objectAtIndex:[indexPath row] - [self.sitemaps count] - 1]).tag isEqualToString:@"settings"]) {
                UINavigationController *nav =(UINavigationController *)self.mm_drawerController.centerViewController;
                OpenHABSettingsViewController *newViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"OpenHABSettingsViewController"];
                [nav pushViewController:newViewController animated:YES];
            }
            if ([((OpenHABDrawerItem *)[self.drawerItems objectAtIndex:[indexPath row] - [self.sitemaps count] - 1]).tag isEqualToString:@"notifications"]) {
                UINavigationController *nav =(UINavigationController *)self.mm_drawerController.centerViewController;
                if ([[nav visibleViewController] isKindOfClass:[OpenHABNotificationsViewControllerTableViewController class]]) {
                    NSLog(@"Notifications are already open");
                } else {
                    OpenHABNotificationsViewControllerTableViewController *newViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"OpenHABNotificationsViewController"];
                    [nav pushViewController:newViewController animated:YES];
                }
            }
        }
    }
    [self.mm_drawerController closeDrawerAnimated:YES completion:nil];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)loadSettings
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    self.openHABUsername = [prefs valueForKey:@"username"];
    self.openHABPassword = [prefs valueForKey:@"password"];
    self.ignoreSSLCertificate = [prefs boolForKey:@"ignoreSSL"];
}

// App wide data access

- (OpenHABDataObject*)appData
{
    id<OpenHABAppDataDelegate> theDelegate = (id<OpenHABAppDataDelegate>) [UIApplication sharedApplication].delegate;
    return [theDelegate appData];
}

@end
