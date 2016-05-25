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
#import "ChartUITableViewCell.h"
#import <GAI.h>
#import "GAIFields.h"
#import "GAIDictionaryBuilder.h"
#import "UIAlertView+Block.h"
#import "UIViewController+MMDrawerController.h"
#import "MMDrawerBarButtonItem.h"
#import "OpenHABDrawerTableViewController.h"

@interface OpenHABViewController ()

@end

@implementation OpenHABViewController {
    long selectedWidgetRow;
    AFHTTPRequestOperation *currentPageOperation;
    AFHTTPRequestOperation *commandOperation;
}

@synthesize pageUrl, widgetTableView, openHABRootUrl, openHABUsername, openHABPassword, ignoreSSLCertificate, sitemaps, currentPage, pageNetworkStatus, pageNetworkStatusAvailable, idleOff, deviceId, deviceToken, deviceName, refreshControl;


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
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.backgroundColor = [UIColor groupTableViewBackgroundColor];
//    self.refreshControl.tintColor = [UIColor whiteColor];
    [self.refreshControl addTarget:self action:@selector(handleRefresh:) forControlEvents:UIControlEventValueChanged];
    [self.widgetTableView addSubview:self.refreshControl];
    [self.widgetTableView sendSubviewToBack:refreshControl];
    MMDrawerBarButtonItem * rightDrawerButton = [[MMDrawerBarButtonItem alloc] initWithTarget:self action:@selector(rightDrawerButtonPress:)];
    [self.navigationItem setRightBarButtonItem:rightDrawerButton animated:YES];
}

- (void)handleRefresh:(UIRefreshControl *)refreshControl {
    [self loadPage:NO];
//    [self.widgetTableView reloadData];
//    [self.widgetTableView layoutIfNeeded];
}

- (void)handleApsRegistration:(NSNotification *)note
{
    NSLog(@"handleApsRegistration");
    NSDictionary *theData = [note userInfo];
    if (theData != nil) {
        self.deviceId = [theData objectForKey:@"deviceId"];
        self.deviceToken = [theData objectForKey:@"deviceToken"];
        self.deviceName = [theData objectForKey:@"deviceName"];
        [self doRegisterAps];
    }
}

-(void)rightDrawerButtonPress:(id)sender{
    OpenHABDrawerTableViewController *drawer = (OpenHABDrawerTableViewController*)[self.mm_drawerController rightDrawerViewController];
    [self.mm_drawerController toggleDrawerSide:MMDrawerSideRight animated:YES completion:nil];
}

- (void) doRegisterAps
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    if ([[prefs valueForKey:@"remoteUrl"] hasPrefix:@"https://my.openhab.org"] ||
        [[prefs valueForKey:@"remoteUrl"] hasPrefix:@"https://home.openhab.org"]) {
        if (deviceId != nil && deviceToken != nil && deviceName != nil) {
            NSLog(@"Registering with my.openHAB");
            NSString *registrationUrlString = [NSString stringWithFormat:@"https://my.openhab.org/addAppleRegistration?regId=%@&deviceId=%@&deviceModel=%@", deviceToken, deviceId, deviceName];
            NSURL *registrationUrl = [[NSURL alloc] initWithString:[registrationUrlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
            NSLog(@"Registration URL = %@", [registrationUrl absoluteString]);
            NSMutableURLRequest *registrationRequest = [NSMutableURLRequest requestWithURL:registrationUrl];
            [registrationRequest setAuthCredentials:self.openHABUsername :self.openHABPassword];
            AFHTTPRequestOperation *registrationOperation = [[AFHTTPRequestOperation alloc] initWithRequest:registrationRequest];
            [registrationOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
                NSLog(@"my.openHAB registration sent");
            } failure:^(AFHTTPRequestOperation *operation, NSError *error){
                NSLog(@"my.openHAB registration failed");
                NSLog(@"Error:------>%@", [error localizedDescription]);
                NSLog(@"error code %ld",(long)[operation.response statusCode]);
            }];
            [registrationOperation start];
        }
    }
}

- (void) viewDidAppear:(BOOL)animated
{
    NSLog(@"OpenHABViewController viewDidAppear");
    [super viewDidAppear:animated];
}

- (void) viewWillAppear:(BOOL)animated
{
    NSLog(@"OpenHABViewController viewWillAppear");
    [super viewDidAppear:animated];
    id gaiTracker = [[GAI sharedInstance] defaultTracker];
    [gaiTracker set:kGAIScreenName
           value:@"OpenHABViewController"];
    [gaiTracker send:[[GAIDictionaryBuilder createAppView] build]];
    // Load settings into local properties
    [self loadSettings];
    // Set authentication parameters to SDImage
    [self setSDImageAuth];
    // Set default controller for TSMessage to self
    [TSMessage setDefaultViewController:self.navigationController];
    // Disable idle timeout if configured in settings
    if (self.idleOff) {
        [UIApplication sharedApplication].idleTimerDisabled = YES;
    }
    [self doRegisterAps];
    // if pageUrl = nil it means we are the first opened OpenHABViewController
    if (pageUrl == nil) {
        // Set self as root view controller
        [[self appData] setRootViewController:self];
        // Add self as observer for APS registration
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

- (void) viewWillDisappear:(BOOL)animated
{
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
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}

- (void) didBecomeActive: (NSNotification *)notification
{
    NSLog(@"OpenHABViewController didBecomeActive");
    // re disable idle off timer
    if (self.idleOff) {
        [UIApplication sharedApplication].idleTimerDisabled = YES;
    }
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
    } else if ([widget.type isEqualToString:@"Video"]) {
        return self.widgetTableView.frame.size.width/1.33333333;
    } else if ([widget.type isEqualToString:@"Image"] || [widget.type isEqualToString:@"Chart"]) {
        if (widget.image != nil) {
            return widget.image.size.height/(widget.image.size.width/self.widgetTableView.frame.size.width);
        } else {
            return 44;
        }
    } else if ([widget.type isEqualToString:@"Webview"]) {
        if (widget.height != nil) {
            // calculate webview height and return it
            NSLog(@"Webview height would be %f", [widget.height floatValue]*44);
            return [widget.height floatValue]*44;
        } else {
            // return default height for webview as 8 rows
            return 44*8;
        }
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
    } else if ([widget.type isEqualToString:@"Colorpicker"]) {
        cellIdentifier = @"ColorPickerWidgetCell";
    } else if ([widget.type isEqualToString:@"Chart"]) {
        cellIdentifier = @"ChartWidgetCell";
    } else if ([widget.type isEqualToString:@"Image"]) {
        cellIdentifier = @"ImageWidgetCell";
    } else if ([widget.type isEqualToString:@"Video"]) {
        cellIdentifier = @"VideoWidgetCell";
    } else if ([widget.type isEqualToString:@"Webview"]) {
        cellIdentifier = @"WebWidgetCell";
    }

    GenericUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    // No icon is needed for image, video, frame and web widgets
    if (widget.icon != nil && !([cellIdentifier isEqualToString:@"ChartWidgetCell"] || [cellIdentifier isEqualToString:@"ImageWidgetCell"] || [cellIdentifier isEqualToString:@"VideoWidgetCell"] || [cellIdentifier isEqualToString:@"FrameWidgetCell"] || [cellIdentifier isEqualToString:@"WebWidgetCell"])) {
        
        NSString *iconUrlString = nil;
        
        if ([self appData].openHABVersion == 2) {
            iconUrlString = [NSString stringWithFormat:@"%@/icon/%@?state=%@", self.openHABRootUrl, widget.icon, [widget.item.state stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        } else {
            iconUrlString = [NSString stringWithFormat:@"%@/images/%@.png", self.openHABRootUrl, widget.icon];
        }
        
        [cell.imageView sd_setImageWithURL:[NSURL URLWithString:iconUrlString] placeholderImage:[UIImage imageNamed:@"blankicon.png"] options:0];
    }
    if ([cellIdentifier isEqualToString:@"ColorPickerWidgetCell"]) {
        ((ColorPickerUITableViewCell*)cell).delegate = self;
    }
    if ([cellIdentifier isEqualToString:@"ChartWidgetCell"]) {
        NSLog(@"Setting cell base url to %@", self.openHABRootUrl);
        ((ChartUITableViewCell*)cell).baseUrl = self.openHABRootUrl;
    }
    if ([cellIdentifier isEqualToString:@"ChartWidgetCell"] || [cellIdentifier isEqualToString:@"ImageWidgetCell"]) {
        [(ImageUITableViewCell *)cell setDelegate:self];
    }
    if ([cellIdentifier isEqualToString:@"FrameWidgetCell"]) {
        cell.backgroundColor = [UIColor groupTableViewBackgroundColor];
    } else {
        cell.backgroundColor = [UIColor whiteColor];
    }
    [cell loadWidget:widget];
    [cell displayWidget];
    // Check if this is not the last row in the widgets list
    if (indexPath.row < [currentPage.widgets count] - 1) {
        OpenHABWidget *nextWidget = [currentPage.widgets objectAtIndex:indexPath.row + 1];
        if ([nextWidget.type isEqual:@"Frame"] || [nextWidget.type isEqual:@"Image"] || [nextWidget.type isEqual:@"Video"] || [nextWidget.type isEqual:@"Webview"] || [nextWidget.type isEqual:@"Chart"]) {
            cell.separatorInset = UIEdgeInsetsZero;
        } else if (![widget.type isEqualToString:@"Frame"]) {
            cell.separatorInset = UIEdgeInsetsMake(0, 60, 0, 0);
        }
    }
    return cell;
}

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Prevent the cell from inheriting the Table View's margin settings
    if ([cell respondsToSelector:@selector(setPreservesSuperviewLayoutMargins:)]) {
        [cell setPreservesSuperviewLayoutMargins:NO];
    }
    
    // Explictly set your cell's layout margins
    if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
        [cell setLayoutMargins:UIEdgeInsetsZero];
    }
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

- (void)didLoadImage
{
    [self.widgetTableView reloadData];
}

- (void)evaluateServerTrust:(AFRememberingSecurityPolicy *)policy summary:(NSString *)certificateSummary forDomain:(NSString *)domain
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"SSL Certificate Warning" message:[NSString stringWithFormat:@"SSL Certificate presented by %@ for %@ is invalid. Do you want to proceed?", certificateSummary, domain] delegate:nil cancelButtonTitle:NSLocalizedString(@"Abort", @"") otherButtonTitles:@"Once", @"Always", nil];
        [alertView showWithCompletion:^(UIAlertView *alertView, NSInteger buttonIndex) {
            if (buttonIndex == 0)
                [policy deny];
            else if (buttonIndex == 1)
                [policy permitOnce];
            else if (buttonIndex == 2)
                [policy permitAlways];
        }];
    });
}

- (void) evaluateCertificateMismatch:(AFRememberingSecurityPolicy *)policy summary:(NSString *)certificateSummary forDomain:(NSString *)domain
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"SSL Certificate Warning" message:[NSString stringWithFormat:@"SSL Certificate presented by %@ for %@ is doesn't match the record. Do you want to proceed?", certificateSummary, domain] delegate:nil cancelButtonTitle:NSLocalizedString(@"Abort", @"") otherButtonTitles:@"Once", @"Always", nil];
        [alertView showWithCompletion:^(UIAlertView *alertView, NSInteger buttonIndex) {
            if (buttonIndex == 0)
                [policy deny];
            else if (buttonIndex == 1)
                [policy permitOnce];
            else if (buttonIndex == 2)
                [policy permitAlways];
        }];
    });
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
    [TSMessage showNotificationInViewController:self.navigationController title:@"Connecting" subtitle:message image:nil type:TSMessageNotificationTypeMessage duration:3.0 callback:nil buttonTitle:nil buttonCallback:nil atPosition:TSMessageNotificationPositionBottom canBeDismissedByUser:YES];
}

- (void)openHABTrackingError:(NSError *)error
{
    NSLog(@"OpenHABViewController discovery error");
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [TSMessage showNotificationInViewController:self.navigationController title:@"Error" subtitle:[error localizedDescription] image:nil type:TSMessageNotificationTypeError duration:60.0 callback:nil buttonTitle:nil buttonCallback:nil atPosition:TSMessageNotificationPositionBottom canBeDismissedByUser:YES];
}

- (void)openHABTracked:(NSString *)openHABUrl
{
    NSLog(@"OpenHABViewController openHAB URL = %@", openHABUrl);
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    self.openHABRootUrl = openHABUrl;
    [[self appData] setOpenHABRootUrl:openHABRootUrl];
    // Checking openHAB version
    NSURL *pageToLoadUrl = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@/rest/bindings", self.openHABRootUrl]];
    NSMutableURLRequest *pageRequest = [NSMutableURLRequest requestWithURL:pageToLoadUrl];
    [pageRequest setAuthCredentials:self.openHABUsername :self.openHABPassword];
    [pageRequest setTimeoutInterval:10.0];
    AFHTTPRequestOperation *versionPageOperation = [[AFHTTPRequestOperation alloc] initWithRequest:pageRequest];
    AFRememberingSecurityPolicy *policy = [AFRememberingSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    [policy setDelegate:self];
    currentPageOperation.securityPolicy = policy;
    if (self.ignoreSSLCertificate) {
        NSLog(@"Warning - ignoring invalid certificates");
        currentPageOperation.securityPolicy.allowInvalidCertificates = YES;
    }
    [versionPageOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"This is an openHAB 2.X");
        [[self appData] setOpenHABVersion:2];
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        NSData *response = (NSData*)responseObject;
        NSError *error;
        [self selectSitemap];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error){
        NSLog(@"This is an openHAB 1.X");
        [[self appData] setOpenHABVersion:1];
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        NSLog(@"Error:------>%@", [error description]);
        NSLog(@"error code %ld",(long)[operation.response statusCode]);
        [self selectSitemap];
    }];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [versionPageOperation start];
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
    if (commandOperation != nil) {
        [commandOperation cancel];
        commandOperation = nil;
    }
    commandOperation = [[AFHTTPRequestOperation alloc] initWithRequest:commandRequest];
    AFRememberingSecurityPolicy *policy = [AFRememberingSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    [policy setDelegate:self];
    commandOperation.securityPolicy = policy;
    if (self.ignoreSSLCertificate) {
        NSLog(@"Warning - ignoring invalid certificates");
        commandOperation.securityPolicy.allowInvalidCertificates = YES;
    }
    [commandOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"Command sent!");
    } failure:^(AFHTTPRequestOperation *operation, NSError *error){
        NSLog(@"Error:------>%@", [error localizedDescription]);
        NSLog(@"error code %ld",(long)[operation.response statusCode]);
    }];
    NSLog(@"Timeout %f", commandRequest.timeoutInterval);
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

- (void) didPressColorButton:(ColorPickerUITableViewCell *)cell
{
    ColorPickerViewController *colorPickerViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"ColorPickerViewController"];;
    colorPickerViewController.widget = [self.currentPage.widgets objectAtIndex:[self.widgetTableView indexPathForCell:cell].row];
    [self.navigationController pushViewController:colorPickerViewController animated:YES];
}

// load our page and show it into UITableView

- (void)loadPage:(Boolean)longPolling
{
    if (self.pageUrl == nil) {
        return;
    }
    NSLog(@"pageUrl = %@", self.pageUrl);
    // If this is the first request to the page make a bulk call to pageNetworkStatusChanged
    // to save current reachability status.
    if (!longPolling)
        [self pageNetworkStatusChanged];
    NSURL *pageToLoadUrl = [[NSURL alloc] initWithString:self.pageUrl];
    NSMutableURLRequest *pageRequest = [NSMutableURLRequest requestWithURL:pageToLoadUrl];
    [pageRequest setAuthCredentials:self.openHABUsername :self.openHABPassword];
    // We accept XML only if openHAB is 1.X
    if ([self appData].openHABVersion == 1) {
        [pageRequest setValue:@"application/xml" forHTTPHeaderField:@"Accept"];
    }
    [pageRequest setValue:@"1.0" forHTTPHeaderField:@"X-Atmosphere-Framework"];
    if (longPolling) {
        NSLog(@"long polling, so setting atmosphere transport");
        [pageRequest setValue:@"long-polling" forHTTPHeaderField:@"X-Atmosphere-Transport"];
        [pageRequest setTimeoutInterval:300.0];
    } else {
        self.atmosphereTrackingId = nil;
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
        [pageRequest setTimeoutInterval:10.0];
    }
    if (self.atmosphereTrackingId != nil) {
        [pageRequest setValue:self.atmosphereTrackingId forHTTPHeaderField:@"X-Atmosphere-tracking-id"];
    } else {
        [pageRequest setValue:@"0" forHTTPHeaderField:@"X-Atmosphere-tracking-id"];
    }
    if (currentPageOperation != nil) {
        [currentPageOperation cancel];
        currentPageOperation = nil;
    }
    currentPageOperation = [[AFHTTPRequestOperation alloc] initWithRequest:pageRequest];
    // If we are talking to openHAB 2+, we expect response to be JSON
    if ([self appData].openHABVersion == 2) {
        NSLog(@"Setting setializer to JSON");
        currentPageOperation.responseSerializer = [AFJSONResponseSerializer serializer];
    }
    AFRememberingSecurityPolicy *policy = [AFRememberingSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    [policy setDelegate:self];
    currentPageOperation.securityPolicy = policy;
    if (self.ignoreSSLCertificate) {
        NSLog(@"Warning - ignoring invalid certificates");
        currentPageOperation.securityPolicy.allowInvalidCertificates = YES;
    }
    [currentPageOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"Page loaded with success");
        NSDictionary *headers = operation.response.allHeaderFields;
//        NSLog(@"%@", headers);
        if ([headers objectForKey:@"X-Atmosphere-tracking-id"] != nil) {
            NSLog(@"Found X-Atmosphere-tracking-id: %@", [headers objectForKey:@"X-Atmosphere-tracking-id"]);
            self.atmosphereTrackingId = [headers objectForKey:@"X-Atmosphere-tracking-id"];
        }
        NSData *response = (NSData*)responseObject;
        NSError *error;
        // If we are talking to openHAB 1.X, talk XML
        if ([self appData].openHABVersion == 1) {
            GDataXMLDocument *doc = [[GDataXMLDocument alloc] initWithData:response error:&error];
            if (doc == nil) return;
            NSLog(@"%@", [doc.rootElement name]);
            if ([[doc.rootElement name] isEqual:@"page"]) {
                currentPage = [[OpenHABSitemapPage alloc] initWithXML:doc.rootElement];
            } else {
                NSLog(@"Unable to find page root element");
                return;
            }
        // Newer versions talk JSON!
        } else {
            currentPage = [[OpenHABSitemapPage alloc] initWithDictionary:responseObject];
        }
        [currentPage setDelegate:self];
        [self.widgetTableView reloadData];
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        [self.refreshControl endRefreshing];
        self.navigationItem.title = [self.currentPage.title componentsSeparatedByString:@"["][0];
        if (longPolling == YES)
            [self loadPage:NO];
        else
            [self loadPage:YES];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error){
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        NSLog(@"Error:------>%@", [error description]);
        NSLog(@"error code %ld",(long)[operation.response statusCode]);
        self.atmosphereTrackingId = nil;
        if (error.code == -1001 && longPolling) {
            NSLog(@"Timeout, restarting requests");
            [self loadPage:NO];
        } else if (error.code == -999) {
            // Request was cancelled
            NSLog(@"Request was cancelled");
        } else {
            // Error
            if (error.code == -1012) {
                [TSMessage showNotificationInViewController:self.navigationController title:@"Error" subtitle:@"SSL Certificate Error" image:nil type:TSMessageNotificationTypeError duration:5.0 callback:nil buttonTitle:nil buttonCallback:nil atPosition:TSMessageNotificationPositionBottom canBeDismissedByUser:YES];
            } else {
                [TSMessage showNotificationInViewController:self.navigationController title:@"Error" subtitle:[error localizedDescription] image:nil type:TSMessageNotificationTypeError duration:5.0 callback:nil buttonTitle:nil buttonCallback:nil atPosition:TSMessageNotificationPositionBottom canBeDismissedByUser:YES];
            }
            NSLog(@"Request failed: %@", [error localizedDescription]);
        }
    }];
    NSLog(@"OpenHABViewController sending new request");
    [currentPageOperation start];
    NSLog(@"OpenHABViewController request sent");
}

// Select sitemap

- (void)selectSitemap
{
    NSString *sitemapsUrlString = [NSString stringWithFormat:@"%@/rest/sitemaps", self.openHABRootUrl];
    NSURL *sitemapsUrl = [[NSURL alloc] initWithString:sitemapsUrlString];
    NSMutableURLRequest *sitemapsRequest = [NSMutableURLRequest requestWithURL:sitemapsUrl];
    [sitemapsRequest setAuthCredentials:self.openHABUsername :self.openHABPassword];
    [sitemapsRequest setTimeoutInterval:10.0];
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:sitemapsRequest];
    AFRememberingSecurityPolicy *policy = [AFRememberingSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    [policy setDelegate:self];
    operation.securityPolicy = policy;
    if (self.ignoreSSLCertificate) {
        NSLog(@"Warning - ignoring invalid certificates");
        operation.securityPolicy.allowInvalidCertificates = YES;
    }
    // If we are talking to openHAB 2+, we expect response to be JSON
    if ([self appData].openHABVersion == 2) {
        NSLog(@"Setting setializer to JSON");
        operation.responseSerializer = [AFJSONResponseSerializer serializer];
    }
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSData *response = (NSData*)responseObject;
        NSError *error;
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        [sitemaps removeAllObjects];
        // If we are talking to openHAB 1.X, talk XML
        if ([self appData].openHABVersion == 1) {
            NSLog(@"%@", [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
            GDataXMLDocument *doc = [[GDataXMLDocument alloc] initWithData:response error:&error];
            if (doc == nil) return;
            NSLog(@"%@", [doc.rootElement name]);
            if ([[doc.rootElement name] isEqual:@"sitemaps"]) {
                for (GDataXMLElement *element in [doc.rootElement elementsForName:@"sitemap"]) {
                    OpenHABSitemap *sitemap = [[OpenHABSitemap alloc] initWithXML:element];
                    [sitemaps addObject:sitemap];
                }
            }
        // Newer versions speak JSON!
        } else {
            if ([responseObject isKindOfClass:[NSArray class]]) {
                NSLog(@"Response is array");
                for (id sitemapJson in responseObject) {
                    OpenHABSitemap *sitemap = [[OpenHABSitemap alloc] initWithDictionaty:sitemapJson];
                    [sitemaps addObject:sitemap];
                }
            } else {
                // Something went wrong, we should have received an array
            }
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
            [TSMessage showNotificationInViewController:self.navigationController title:@"Error" subtitle:@"openHAB returned empty sitemap list" image:nil type:TSMessageNotificationTypeError duration:5.0 callback:nil buttonTitle:nil buttonCallback:nil atPosition:TSMessageNotificationPositionBottom canBeDismissedByUser:YES];
        }

    } failure:^(AFHTTPRequestOperation *operation, NSError *error){
        NSLog(@"Error:------>%@", [error description]);
        NSLog(@"error code %ld",(long)[operation.response statusCode]);
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        // Error
        if (error.code == -1012) {
            [TSMessage showNotificationInViewController:self.navigationController title:@"Error" subtitle:@"SSL Certificate Error" image:nil type:TSMessageNotificationTypeError duration:5.0 callback:nil buttonTitle:nil buttonCallback:nil atPosition:TSMessageNotificationPositionBottom canBeDismissedByUser:YES];
        } else {
            [TSMessage showNotificationInViewController:self.navigationController title:@"Error" subtitle:[error localizedDescription] image:nil type:TSMessageNotificationTypeError duration:5.0 callback:nil buttonTitle:nil buttonCallback:nil atPosition:TSMessageNotificationPositionBottom canBeDismissedByUser:YES];
        }
    }];
    NSLog(@"Firing request");
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
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
    self.idleOff = [prefs boolForKey:@"idleOff"];
    [[self appData] setOpenHABUsername:self.openHABUsername];
    [[self appData] setOpenHABPassword:self.openHABPassword];
}

// Set SDImage (used for widget icons and images) authentication

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
    NSLog(@"OpenHABViewController pageNetworkStatusChange");
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
