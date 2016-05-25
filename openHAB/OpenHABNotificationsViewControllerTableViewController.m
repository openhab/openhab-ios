//
//  OpenHABNotificationsViewControllerTableViewController.m
//  openHAB
//
//  Created by Victor Belov on 24/05/16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//

#import "OpenHABNotificationsViewControllerTableViewController.h"

@interface OpenHABNotificationsViewControllerTableViewController ()

@end

@implementation OpenHABNotificationsViewControllerTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
/*    NSString *sitemapsUrlString = [NSString stringWithFormat:@"%@/rest/sitemaps", self.openHABRootUrl];
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
    [operation start];*/
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
#warning Incomplete implementation, return the number of sections
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
#warning Incomplete implementation, return the number of rows
    return 0;
}

/*
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:<#@"reuseIdentifier"#> forIndexPath:indexPath];
    
    // Configure the cell...
    
    return cell;
}
*/

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
