//
//  OpenHABNotificationsViewControllerTableViewController.m
//  openHAB
//
//  Created by Victor Belov on 24/05/16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//

#import "OpenHABNotificationsViewControllerTableViewController.h"
#import "OpenHABAppDataDelegate.h"
#import "OpenHABDataObject.h"
#import "NSMutableURLRequest+Auth.h"
#import "AFNetworking.h"
#import "AFRememberingSecurityPolicy.h"
#import "OpenHABNotification.h"
#import "NSDate+Helper.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import <SDWebImage/SDWebImageDownloader.h>
#import "UIViewController+MMDrawerController.h"
#import "MMDrawerBarButtonItem.h"
#import "OpenHABDrawerTableViewController.h"
#import "NotificationTableViewCell.h"


@interface OpenHABNotificationsViewControllerTableViewController ()

@end

@implementation OpenHABNotificationsViewControllerTableViewController

@synthesize openHABUsername, openHABRootUrl, openHABPassword, ignoreSSLCertificate, notifications;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.notifications = [NSMutableArray array];
    self.tableView.tableFooterView = [[UIView alloc] init];
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.backgroundColor = [UIColor groupTableViewBackgroundColor];
    //    self.refreshControl.tintColor = [UIColor whiteColor];
    [self.refreshControl addTarget:self action:@selector(handleRefresh:) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];
    [self.tableView sendSubviewToBack:self.refreshControl];
    MMDrawerBarButtonItem * rightDrawerButton = [[MMDrawerBarButtonItem alloc] initWithTarget:self action:@selector(rightDrawerButtonPress:)];
    [self.navigationItem setRightBarButtonItem:rightDrawerButton animated:YES];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self loadSettings];
    [self loadNotifications];
}

- (void)loadNotifications {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    NSString *notificationsUrlString = [NSString stringWithFormat:@"%@/api/v1/notifications?limit=20", [prefs valueForKey:@"remoteUrl"]];
    NSURL *notificationsUrl = [[NSURL alloc] initWithString:notificationsUrlString];
    NSMutableURLRequest *notificationsRequest = [NSMutableURLRequest requestWithURL:notificationsUrl];
    [notificationsRequest setAuthCredentials:self.openHABUsername :self.openHABPassword];
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:notificationsRequest];
    AFRememberingSecurityPolicy *policy = [AFRememberingSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    operation.securityPolicy = policy;
    if (self.ignoreSSLCertificate) {
        NSLog(@"Warning - ignoring invalid certificates");
        operation.securityPolicy.allowInvalidCertificates = YES;
    }
    operation.responseSerializer = [AFJSONResponseSerializer serializer];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSData *response = (NSData*)responseObject;
        NSError *error;
        [self.notifications removeAllObjects];
        NSLog(@"Notifications response");
        // If we are talking to openHAB 1.X, talk XML
        if ([responseObject isKindOfClass:[NSArray class]]) {
            NSLog(@"Response is array");
            for (id notificationJson in responseObject) {
                OpenHABNotification *notification = [[OpenHABNotification alloc] initWithDictionary:notificationJson];
                [notifications addObject:notification];
            }
        } else {
            NSLog(@"Response is not array");
            return;
        }
        [self.refreshControl endRefreshing];
        [self.tableView reloadData];
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    } failure:^(AFHTTPRequestOperation *operation, NSError *error){
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        NSLog(@"Error:------>%@", [error description]);
        NSLog(@"error code %ld",(long)[operation.response statusCode]);
        [self.refreshControl endRefreshing];
    }];
    [operation start];
}

- (void)handleRefresh:(UIRefreshControl *)refreshControl {
    NSLog(@"Refresh pulled");
    [self loadNotifications];
}

-(void)rightDrawerButtonPress:(id)sender{
    OpenHABDrawerTableViewController *drawer = (OpenHABDrawerTableViewController*)[self.mm_drawerController rightDrawerViewController];
    [self.mm_drawerController toggleDrawerSide:MMDrawerSideRight animated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [notifications count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"NotificationCell";
    NotificationTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    OpenHABNotification *notification = [notifications objectAtIndex:[indexPath row]];
    cell.textLabel.text = notification.message;
    // First convert date of notification from UTC from my.OH to local time for device
    NSTimeInterval timeZoneSeconds = [[NSTimeZone localTimeZone] secondsFromGMT];
    NSDate *createdInLocalTimezone = [notification.created dateByAddingTimeInterval:timeZoneSeconds];
    cell.detailTextLabel.text = [NSDate stringForDisplayFromDate:createdInLocalTimezone];
    
    NSString *iconUrlString = nil;
    if ([self appData].openHABVersion == 2) {
        iconUrlString = [NSString stringWithFormat:@"%@/icon/%@.png", [self appData].openHABRootUrl, notification.icon];
    } else {
        iconUrlString = [NSString stringWithFormat:@"%@/images/%@.png", [self appData].openHABRootUrl, notification.icon];
    }
    NSLog(@"%@", iconUrlString);
    [cell.imageView sd_setImageWithURL:[NSURL URLWithString:iconUrlString] placeholderImage:[UIImage imageNamed:@"icon-29x29.png"] options:0];
    if ([cell respondsToSelector:@selector(setPreservesSuperviewLayoutMargins:)]) {
        [cell setPreservesSuperviewLayoutMargins:NO];
    }
    // Explictly set your cell's layout margins
    if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
        [cell setLayoutMargins:UIEdgeInsetsZero];
    }
    cell.separatorInset = UIEdgeInsetsMake(0, 60, 0, 0);
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // open a alert with an OK and cancel button
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

- (void)loadSettings
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    self.openHABUsername = [prefs valueForKey:@"username"];
    self.openHABPassword = [prefs valueForKey:@"password"];
    self.ignoreSSLCertificate = [prefs boolForKey:@"ignoreSSL"];
//    self.defaultSitemap = [prefs valueForKey:@"defaultSitemap"];
//    self.idleOff = [prefs boolForKey:@"idleOff"];
    [[self appData] setOpenHABUsername:self.openHABUsername];
    [[self appData] setOpenHABPassword:self.openHABPassword];
}

- (OpenHABDataObject*)appData
{
    id<OpenHABAppDataDelegate> theDelegate = (id<OpenHABAppDataDelegate>) [UIApplication sharedApplication].delegate;
    return [theDelegate appData];
}

@end
