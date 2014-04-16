//
//  OpenHABViewController.m
//  openHAB
//
//  Created by Victor Belov on 12/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "OpenHABViewController.h"
#import "OpenHABSelectSitemapViewController.h"
#import "OpenHABTracker.h"
#import "AFNetworking.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import <SDWebImage/SDWebImageDownloader.h>
#import "GDataXMLNode.h"
#import "OpenHABSitemap.h"
#import "NSMutableURLRequest+Auth.h"
#import "OpenHABDataObject.h"
#import "OpenHABAppDataDelegate.h"
#import "OpenHABSitemapPage.h"
#import "OpenHABWidget.h"
#import "OpenHABWidgetMapping.h"
#import "FrameUITableViewCell.h"
#import "OpenHABLinkedPage.h"
#import "OpenHABItem.h"
#import "TSMessage.h"
#import "Reachability+URL.h"

@interface OpenHABViewController ()

@end

@implementation OpenHABViewController {
    long selectedWidgetRow;
    AFHTTPRequestOperation *currentPageOperation;
}

@synthesize pageUrl, widgetTableView, openHABRootUrl, openHABUsername, openHABPassword, ignoreSSLCertificate, sitemaps, currentPage, selectionPicker, pageNetworkStatus, pageNetworkStatusAvailable;


// Here goes everything about view loading, appearing, disappearing, entering background and becoming active

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSLog(@"OpenHABViewController viewDidLoad");
    self.pageNetworkStatus = -1;
    sitemaps = [[NSMutableArray alloc] init];
    self.widgetTableView.tableFooterView = [[UIView alloc] init] ;
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(didEnterBackground:)
                                                 name: UIApplicationDidEnterBackgroundNotification
                                               object: nil];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(didBecomeActive:)
                                                 name: UIApplicationDidBecomeActiveNotification
                                               object: nil];
}

- (void)handleApsRegistration:(NSNotification *)note {
    NSLog(@"handleApsRegistration");
    NSDictionary *theData = [note userInfo];
    if (theData != nil) {
//        NSNumber *n = [theData objectForKey:@"isReachable"];
    }
}

- (void) viewDidAppear:(BOOL)animated {
    NSLog(@"OpenHABViewController viewDidAppear");
    [super viewDidAppear:animated];
    [self loadSettings];
    [self setSDImageAuth];
    [TSMessage setDefaultViewController:self.navigationController];
    if (pageUrl == nil) {
        [[self appData] setRootViewController:self];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleApsRegistration:)
                                                     name:@"apsRegistered"
                                                   object:nil];
        if (self.currentPage != nil) {
            [self.currentPage.widgets removeAllObjects];
            [self.widgetTableView reloadData];
        }
        NSLog(@"OpenHABViewController pageUrl is empty, this is first launch");
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
        tracker = [[OpenHABTracker alloc] init];
        [tracker setDelegate:self];
        [tracker startTracker];
    } else {
        if (![self pageNetworkStatusChanged]) {
            NSLog(@"OpenHABViewController pageUrl = %@, loading page", pageUrl);
            [self loadPage:NO];
        } else {
            NSLog(@"OpenHABViewController network status changed while I was not appearing");
            [self restart];
        }
    }
}

- (void) viewWillDisappear:(BOOL)animated {
    NSLog(@"OpenHABViewController viewWillDisappear");
    if (currentPageOperation != nil) {
        [currentPageOperation cancel];
        currentPageOperation = nil;
    }
    [super viewWillDisappear:animated];
}

- (void) didEnterBackground: (NSNotification *)notification
{
    NSLog(@"OpenHABViewController didEnterBackground");
    if (currentPageOperation != nil) {
        [currentPageOperation cancel];
        currentPageOperation = nil;
    }
}

- (void) didBecomeActive: (NSNotification *)notification
{
    NSLog(@"OpenHABViewController didBecomeActive");
    if (self.isViewLoaded && self.view.window && self.pageUrl != nil) {
        if (![self pageNetworkStatusChanged]) {
            NSLog(@"OpenHABViewController isViewLoaded, restarting network activity");
            [self loadPage:NO];
        } else {
            NSLog(@"OpenHABViewController network status changed while i was inactive");
            [self restart];
        }
    }
}

- (void) restart
{
    if ([[self appData] rootViewController] == self) {
        NSLog(@"I am a rootViewController!");
    } else {
        [[self appData] rootViewController].pageUrl = nil;
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
}

// Here goes everything about our main UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.currentPage != nil)
        return [[self.currentPage widgets] count];
    else
        return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    OpenHABWidget *widget = [[self.currentPage widgets] objectAtIndex:indexPath.row];
    if ([widget.type isEqualToString:@"Frame"]) {
        if (widget.label.length > 0)
            return 35;
        else
            return 0;
    }
    return 44;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    OpenHABWidget *widget = [[self.currentPage widgets] objectAtIndex:indexPath.row];
    NSString *cellIdentifier = @"GenericWidgetCell";
    if ([widget.type isEqualToString:@"Frame"]) {
        cellIdentifier = @"FrameWidgetCell";
    } else if ([widget.type isEqualToString:@"Switch"]) {
        if ([widget.mappings count] > 0) {
            cellIdentifier = @"SegmentedWidgetCell";
        } else if ([widget.item.type isEqualToString:@"RollershutterItem"]) {
            cellIdentifier = @"RollershutterWidgetCell";
        } else {
            cellIdentifier = @"SwitchWidgetCell";
        }
    } else if ([widget.type isEqualToString:@"Setpoint"]) {
        cellIdentifier = @"SetpointWidgetCell";
    } else if ([widget.type isEqualToString:@"Slider"]) {
        cellIdentifier = @"SliderWidgetCell";
    } else if ([widget.type isEqualToString:@"Selection"]) {
        cellIdentifier = @"SelectionWidgetCell";
    }

    GenericUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    [cell loadWidget:widget];
    [cell displayWidget];
    if (widget.icon != nil) {
        NSString *iconUrlString = [NSString stringWithFormat:@"%@/images/%@.png", self.openHABRootUrl, widget.icon];
        [cell.imageView setImageWithURL:[NSURL URLWithString:iconUrlString] placeholderImage:[UIImage imageNamed:@"blankicon.png"] options:0];
    }
    // Check if this is not the last row in the widgets list
    if (indexPath.row < [currentPage.widgets count] - 1) {
        OpenHABWidget *nextWidget = [currentPage.widgets objectAtIndex:indexPath.row + 1];
        if ([nextWidget.type isEqual:@"Frame"]) {
            cell.separatorInset = UIEdgeInsetsZero;
        } else if (![widget.type isEqualToString:@"Frame"]) {
            cell.separatorInset = UIEdgeInsetsMake(0, 60, 0, 0);
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    OpenHABWidget *widget = [currentPage.widgets objectAtIndex:indexPath.row];
    if (widget.linkedPage != nil) {
        NSLog(@"Selected %@", widget.linkedPage.link);
        selectedWidgetRow = indexPath.row;
        OpenHABViewController *newViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"OpenHABPageViewController"];
        newViewController.pageUrl = widget.linkedPage.link;
        newViewController.openHABRootUrl = self.openHABRootUrl;
        [self.navigationController pushViewController:newViewController animated:YES];
    } else if ([widget.type isEqualToString:@"Selection"]) {
        NSLog(@"Selected selection widget");
        selectedWidgetRow = indexPath.row;
        OpenHABSelectionTableViewController *selectionViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"OpenHABSelectionTableViewController"];;
        OpenHABWidget *selectedWidget = [self.currentPage.widgets objectAtIndex:selectedWidgetRow];
        selectionViewController.mappings = selectedWidget.mappings;
        selectionViewController.delegate = self;
        selectionViewController.selectionItem = selectedWidget.item;
        [self.navigationController pushViewController:selectionViewController animated:YES];
    }
    [self.widgetTableView deselectRowAtIndexPath:[self.widgetTableView indexPathForSelectedRow] animated:NO];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSLog(@"OpenHABViewController prepareForSegue %@", segue.identifier);
    if ([segue.identifier isEqual:@"showPage"]) {
        OpenHABViewController *newViewController = (OpenHABViewController *)segue.destinationViewController;
        OpenHABWidget *selectedWidget = [self.currentPage.widgets objectAtIndex:selectedWidgetRow];
        newViewController.pageUrl = selectedWidget.linkedPage.link;
        newViewController.openHABRootUrl = self.openHABRootUrl;
    } else if ([segue.identifier isEqual:@"showSelectionView"]) {
        NSLog(@"Selection seague");
    }
}

// OpenHABTracker delegate methods

- (void)openHABTrackingProgress:(NSString *)message
{
    NSLog(@"OpenHABViewController %@", message);
//    [TSMessage showNotificationWithTitle:@"Connecting" subtitle:message type:TSMessageNotificationTypeMessage];
    [TSMessage showNotificationInViewController:self.navigationController title:@"Connecting" subtitle:message type:TSMessageNotificationTypeMessage duration:3.0 callback:nil buttonTitle:nil buttonCallback:nil atPosition:TSMessageNotificationPositionBottom canBeDismisedByUser:YES];
}

- (void)openHABTrackingError:(NSError *)error
{
    NSLog(@"OpenHABViewController discovery error");
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [TSMessage showNotificationInViewController:self.navigationController title:@"Error" subtitle:[error localizedDescription] type:TSMessageNotificationTypeError duration:60.0 callback:nil buttonTitle:nil buttonCallback:nil atPosition:TSMessageNotificationPositionBottom canBeDismisedByUser:YES];
//    [TSMessage showNotificationWithTitle:@"Test" subtitle:@"Test subtitle" type:TSMessageNotificationTypeError];
}

- (void)openHABTracked:(NSString *)openHABUrl
{
    NSLog(@"OpenHABViewController openHAB URL = %@", openHABUrl);
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    self.openHABRootUrl = openHABUrl;
    [[self appData] setOpenHABRootUrl:openHABRootUrl];
    [self selectSitemap];
}

// send command to an item

- (void)sendCommand:(OpenHABItem *)item commandToSend:(NSString *)command
{
    NSURL *commandUrl = [[NSURL alloc] initWithString:item.link];
    NSMutableURLRequest *commandRequest = [NSMutableURLRequest requestWithURL:commandUrl];
    [commandRequest setHTTPMethod:@"POST"];
    [commandRequest setHTTPBody:[command dataUsingEncoding:NSUTF8StringEncoding]];
    [commandRequest setAuthCredentials:self.openHABUsername :self.openHABPassword];
    [commandRequest setValue:@"text/plain" forHTTPHeaderField:@"Content-type"];
    AFHTTPRequestOperation *commandOperation = [[AFHTTPRequestOperation alloc] initWithRequest:commandRequest];
    [commandOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"Command sent!");
    } failure:^(AFHTTPRequestOperation *operation, NSError *error){
        NSLog(@"Error:------>%@", [error localizedDescription]);
        NSLog(@"error code %ld",(long)[operation.response statusCode]);
    }];
    NSLog(@"OpenHABViewController posting %@ command to %@", command, item.link);
    [commandOperation start];
}

// send command on selected selection widget mapping

- (void)didSelectWidgetMapping:(int)selectedMappingIndex
{
    OpenHABWidget *selectedWidget = [self.currentPage.widgets objectAtIndex:selectedWidgetRow];
    OpenHABWidgetMapping *selectedMapping = [selectedWidget.mappings objectAtIndex:selectedMappingIndex];
    [self sendCommand:selectedWidget.item commandToSend:selectedMapping.command];
}


// load our page and show it into UITableView

- (void)loadPage:(Boolean)longPolling
{
    NSLog(@"pageUrl = %@", self.pageUrl);
    NSLog(@"operations queue size = %d", [AFHTTPRequestOperationManager manager].operationQueue.operationCount);
    Reachability *pageReachability = [Reachability reachabilityWithUrlString:self.pageUrl];
    pageNetworkStatus = [pageReachability currentReachabilityStatus];
    NSURL *pageToLoadUrl = [[NSURL alloc] initWithString:self.pageUrl];
    NSMutableURLRequest *pageRequest = [NSMutableURLRequest requestWithURL:pageToLoadUrl];
    [pageRequest setAuthCredentials:self.openHABUsername :self.openHABPassword];
    [pageRequest setValue:@"application/xml" forHTTPHeaderField:@"Accept"];
    if (longPolling) {
        NSLog(@"long polling, so setting atmosphere transport");
        [pageRequest setValue:@"long-polling" forHTTPHeaderField:@"X-Atmosphere-Transport"];
    } else {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    }
    if (currentPageOperation != nil) {
        [currentPageOperation cancel];
        currentPageOperation = nil;
    }
    currentPageOperation = [[AFHTTPRequestOperation alloc] initWithRequest:pageRequest];
    if (self.ignoreSSLCertificate) {
        NSLog(@"Warning - ignoring invalid certificates");
        currentPageOperation.securityPolicy.allowInvalidCertificates = YES;
    }
    [currentPageOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        NSData *response = (NSData*)responseObject;
        NSError *error;
        GDataXMLDocument *doc = [[GDataXMLDocument alloc] initWithData:response error:&error];
        if (doc == nil) return;
        NSLog(@"%@", [doc.rootElement name]);
        if ([[doc.rootElement name] isEqual:@"page"]) {
            currentPage = [[OpenHABSitemapPage alloc] initWithXML:doc.rootElement];
            [currentPage setDelegate:self];
//            for (OpenHABWidget *widget in [self.currentPage widgets]) {
//                NSLog(@"%@ - %@", widget.label, widget.type);
//            }
            [self.widgetTableView reloadData];
            self.navigationItem.title = self.currentPage.title;
            [self loadPage:YES];
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error){
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        NSLog(@"Error:------>%@", [error description]);
        NSLog(@"error code %ld",(long)[operation.response statusCode]);
        if (error.code == -1001 && longPolling) {
            [self loadPage:YES];
        } else if (error.code == -999) {
            // Request was cancelled
            NSLog(@"Request was cancelled");
        } else {
            // Error
            [TSMessage showNotificationInViewController:self.navigationController title:@"Error" subtitle:[error localizedDescription] type:TSMessageNotificationTypeError duration:5.0 callback:nil buttonTitle:nil buttonCallback:nil atPosition:TSMessageNotificationPositionBottom canBeDismisedByUser:YES];
            NSLog(@"Request failed: %@", [error localizedDescription]);
        }
    }];
    [currentPageOperation start];
}

// Select sitemap

- (void)selectSitemap
{
    NSString *sitemapsUrlString = [NSString stringWithFormat:@"%@/rest/sitemaps", self.openHABRootUrl];
    NSURL *sitemapsUrl = [[NSURL alloc] initWithString:sitemapsUrlString];
    NSMutableURLRequest *sitemapsRequest = [NSMutableURLRequest requestWithURL:sitemapsUrl];
    [sitemapsRequest setAuthCredentials:self.openHABUsername :self.openHABPassword];
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:sitemapsRequest];
    if (self.ignoreSSLCertificate) {
        NSLog(@"Warning - ignoring invalid certificates");
        operation.securityPolicy.allowInvalidCertificates = YES;
    }
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSData *response = (NSData*)responseObject;
        NSLog(@"%@", [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
        NSError *error;
        GDataXMLDocument *doc = [[GDataXMLDocument alloc] initWithData:response error:&error];
        if (doc == nil) return;
        NSLog(@"%@", [doc.rootElement name]);
        if ([[doc.rootElement name] isEqual:@"sitemaps"]) {
            [sitemaps removeAllObjects];
            for (GDataXMLElement *element in [doc.rootElement elementsForName:@"sitemap"]) {
                OpenHABSitemap *sitemap = [[OpenHABSitemap alloc] initWithXML:element];
                [sitemaps addObject:sitemap];
            }
            [[self appData] setSitemaps:sitemaps];
            if ([sitemaps count] > 0) {
                if ([sitemaps count] > 1) {
                    if (self.defaultSitemap != nil) {
                        OpenHABSitemap *sitemapToOpen = [self sitemapByName:self.defaultSitemap];
                        if (sitemapToOpen != nil) {
                            self.pageUrl = sitemapToOpen.homepageLink;
                            [self loadPage:NO];
                        } else {
                            [self performSegueWithIdentifier:@"showSelectSitemap" sender:self];
                        }
                    } else {
                        [self performSegueWithIdentifier:@"showSelectSitemap" sender:self];
                    }
                } else {
                    self.pageUrl = [[sitemaps objectAtIndex:0] homepageLink];
                    [self loadPage:NO];
                }
            } else {
                // Error - we got 0 sitemaps in the list :-(
                [TSMessage showNotificationInViewController:self.navigationController title:@"Error" subtitle:@"openHAB returned empty sitemap list" type:TSMessageNotificationTypeError duration:5.0 callback:nil buttonTitle:nil buttonCallback:nil atPosition:TSMessageNotificationPositionBottom canBeDismisedByUser:YES];
            }
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error){
        NSLog(@"Error:------>%@", [error description]);
        NSLog(@"error code %ld",(long)[operation.response statusCode]);
        // Error
        [TSMessage showNotificationInViewController:self.navigationController title:@"Error" subtitle:[error localizedDescription] type:TSMessageNotificationTypeError duration:5.0 callback:nil buttonTitle:nil buttonCallback:nil atPosition:TSMessageNotificationPositionBottom canBeDismisedByUser:YES];
    }];
    [operation start];
}

// load app settings

- (void)loadSettings
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    self.openHABUsername = [prefs valueForKey:@"username"];
    self.openHABPassword = [prefs valueForKey:@"password"];
    self.ignoreSSLCertificate = [prefs boolForKey:@"ignoreSSL"];
    self.defaultSitemap = [prefs valueForKey:@"defaultSitemap"];
    [[self appData] setOpenHABUsername:self.openHABUsername];
    [[self appData] setOpenHABPassword:self.openHABPassword];
}

// Set SDImage (used for widget icons) authentication

- (void)setSDImageAuth
{
    NSString *authStr = [NSString stringWithFormat:@"%@:%@", openHABUsername, openHABPassword];
    NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64EncodedStringWithOptions:0]];
    SDWebImageDownloader *manager = [SDWebImageManager sharedManager].imageDownloader;
    [manager setValue:authValue forHTTPHeaderField:@"Authorization"];
}

// Find and return sitemap by it's name if any

- (OpenHABSitemap*)sitemapByName:(NSString*)sitemapName
{
    for (OpenHABSitemap *sitemap in sitemaps) {
        if ([[sitemap name] isEqualToString:sitemapName]) {
            return sitemap;
        }
    }
    return nil;
}

- (BOOL)pageNetworkStatusChanged
{
    if (self.pageUrl != nil) {
        Reachability *pageReachability = [Reachability reachabilityWithUrlString:self.pageUrl];
        if (!pageNetworkStatusAvailable) {
            pageNetworkStatus = [pageReachability currentReachabilityStatus];
            pageNetworkStatusAvailable = YES;
            return NO;
        } else {
            if (pageNetworkStatus == [pageReachability currentReachabilityStatus]) {
                return NO;
            } else {
                pageNetworkStatus = [pageReachability currentReachabilityStatus];
                return YES;
            }
        }
    }
    return NO;
}

// App wide data access

- (OpenHABDataObject*)appData
{
    id<OpenHABAppDataDelegate> theDelegate = (id<OpenHABAppDataDelegate>) [UIApplication sharedApplication].delegate;
    return [theDelegate appData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
