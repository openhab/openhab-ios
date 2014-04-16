//
//  OpenHABSelectionTableViewController.m
//  openHAB
//
//  Created by Victor Belov on 16/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "OpenHABSelectionTableViewController.h"
#import "OpenHABWidgetMapping.h"

@interface OpenHABSelectionTableViewController ()

@end

@implementation OpenHABSelectionTableViewController
@synthesize mappings, delegate, selectionItem;

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
    
    NSLog(@"I have %d mappings", [mappings count]);
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [mappings count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"SelectionCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    OpenHABWidgetMapping *mapping = [mappings objectAtIndex:indexPath.row];
    cell.textLabel.text = mapping.label;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"Selected mapping %ld", (long)indexPath.row);
    if (self.delegate != nil) {
        [self.delegate didSelectWidgetMapping:indexPath.row];
    }
    [self.navigationController popViewControllerAnimated:YES];
}

@end
