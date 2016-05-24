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

@interface OpenHABDrawerTableViewController ()

@end

@implementation OpenHABDrawerTableViewController
@synthesize sitemaps, ignoreSSLCertificate, openHABRootUrl, openHABUsername, openHABPassword, cellCount, drawerItems;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.tableFooterView = [[UIView alloc] init] ;
    self.drawerItems = [NSMutableArray array];
    NSLog(@"OpenHABDrawerTableViewController did load");
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.drawerItems removeAllObjects];
    // check if we are using my.openHAB, add notifications menu item then
    if ([self.openHABRootUrl hasPrefix:@"https://my.openhab.org"] ||
        [self.openHABRootUrl hasPrefix:@"https://home.openhab.org"]) {
        
    }
    // Settings always go last
    OpenHABDrawerItem *settingsItem = [[OpenHABDrawerItem alloc] init];
    settingsItem.label = @"Settings";
    settingsItem.tag = @"settings";
    settingsItem.icon = @"glyphicons-137-cogwheel.png";
    [self.drawerItems addObject:settingsItem];
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
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    if ([indexPath row] != 0) {
        // First sitemaps
        if ([indexPath row] <= [self.sitemaps count] && [sitemaps count] > 0) {
            cell.textLabel.text = ((OpenHABSitemap *)[sitemaps objectAtIndex:[indexPath row] - 1]).label;
            NSString *iconUrlString = nil;
            iconUrlString = [NSString stringWithFormat:@"%@/images/%@.png", self.openHABRootUrl, ((OpenHABSitemap *)[sitemaps objectAtIndex:[indexPath row] - 1]).icon];
            [cell.imageView sd_setImageWithURL:[NSURL URLWithString:iconUrlString] placeholderImage:[UIImage imageNamed:@"icon-29x29.png"] options:0];
        } else {
            // Then menu items
            cell.textLabel.text = ((OpenHABDrawerItem *)[self.drawerItems objectAtIndex:[indexPath row] - [self.sitemaps count] - 1]).label;
            NSString *iconUrlString = nil;
            [cell.imageView sd_setImageWithURL:[NSURL URLWithString:iconUrlString] placeholderImage:[UIImage imageNamed:((OpenHABDrawerItem *)[self.drawerItems objectAtIndex:[indexPath row] - [self.sitemaps count] - 1]).icon] options:0];
        }
    }
/*    if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
        [cell setSeparatorInset:UIEdgeInsetsZero];
    }*/
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
            // ((OpenHABSitemap *)[sitemaps objectAtIndex:[indexPath row] - 1]).label;
        } else {
            // Then menu items
            if ([((OpenHABDrawerItem *)[self.drawerItems objectAtIndex:[indexPath row] - [self.sitemaps count] - 1]).tag isEqualToString:@"settings"]) {
                UINavigationController *nav =(UINavigationController *)self.mm_drawerController.centerViewController;
                OpenHABSettingsViewController *newViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"OpenHABSettingsViewController"];
                [nav pushViewController:newViewController animated:YES];
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

@end
