//
//  OpenHABBeaconNotificationTableViewController.m
//  openHAB
//
//  Created by Uwe on 03.06.16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//

#import "OpenHABBeaconNotificationTableViewController.h"
#import "OpenHABAppDelegate.h"
#import "OpenHABBeaconNotificationDetailViewController.h"

@interface OpenHABBeaconNotificationTableViewController ()

@end

@implementation OpenHABBeaconNotificationTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    //self.navigationItem.leftBarButtonItem = self.editButtonItem;
    
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(insertNewNotification:)];
    self.navigationItem.rightBarButtonItem = addButton;
}

- (void)viewDidAppear:(BOOL)animated
{
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)insertNewNotification:(id)sender
{
    // This handler is called when the "Add" button is pressed
    [self performSegueWithIdentifier:@"showDetail" sender:self];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[self appData] beaconLocations].activeBeacons.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BeaconCell" forIndexPath:indexPath];
    
    // Configure the cell...
    
    OpenHABBeaconNotification *beacon = [[[self appData] beaconLocations].activeBeacons objectAtIndex:indexPath.row];
    
    if (beacon.beaconDescription.length)
    {
        cell.textLabel.text = beacon.beaconDescription;
    }
    else
    {
        cell.textLabel.text = beacon.beaconUUID;
    }
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Major: %@ Minor: %@", beacon.beaconMajor?[beacon.beaconMajor stringValue]:@"All", beacon.beaconMinor?[beacon.beaconMinor stringValue]:@"All"];
    
    return cell;
}



// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}



// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        // Delete the row from the data source
        OpenHABBeaconNotification* beacon = [[[self appData] beaconLocations].activeBeacons objectAtIndex:indexPath.row];
        [[[self appData] beaconLocations] removeBeacon:beacon];
        
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert)
    {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }
}


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


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if ([[segue identifier] isEqualToString:@"showDetail"])
    {
        OpenHABBeaconNotificationDetailViewController *vc = [segue destinationViewController];
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        if (indexPath)
        {
            [vc setDetailItem:[[[self appData] beaconLocations].activeBeacons objectAtIndex:indexPath.row]];
        }
    }
}

- (OpenHABDataObject*)appData
{
    id<OpenHABAppDataDelegate> theDelegate = (id<OpenHABAppDataDelegate>) [UIApplication sharedApplication].delegate;
    return [theDelegate appData];
}

@end