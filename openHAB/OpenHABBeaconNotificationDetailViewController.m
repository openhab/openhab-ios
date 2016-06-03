//
//  OpenHABBeaconNotificationDetailViewController.m
//  openHAB
//
//  Created by Uwe on 03.06.16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//

#import "OpenHABBeaconNotificationDetailViewController.h"
#import "AFNetworking.h"
#import "AFRememberingSecurityPolicy.h"
#import "GDataXMLNode.h"
#import "OpenHABAppDataDelegate.h"
#import "OpenHABDataObject.h"
#import "NSMutableURLRequest+Auth.h"
#import "OpenHABItem.h"


CGFloat animatedDistance;
static const CGFloat KEYBOARD_ANIMATION_DURATION = 0.3;
static const CGFloat MINIMUM_SCROLL_FRACTION = 0.2;
static const CGFloat MAXIMUM_SCROLL_FRACTION = 0.8;
static const CGFloat PORTRAIT_KEYBOARD_HEIGHT = 216;
static const CGFloat LANDSCAPE_KEYBOARD_HEIGHT = 162;

@interface OpenHABBeaconNotificationDetailViewController ()

@property (strong, nonatomic) IBOutlet UITextField* beaconUUID;
@property (strong, nonatomic) IBOutlet UITextField* beaconMajor;
@property (strong, nonatomic) IBOutlet UITextField* beaconMinor;
@property (strong, nonatomic) IBOutlet UITextField* onEnterItem;
@property (strong, nonatomic) IBOutlet UITextField* onLeaveItem;
@property (strong, nonatomic) IBOutlet UISwitch* localNotification;
@property (strong, nonatomic) IBOutlet UITextField *descriptionTextfield;

@property (strong, nonatomic) NSMutableArray* pickerData;
@property (strong, nonatomic) UITextField* textFieldResponder;

@property (strong, nonatomic) OpenHABItem* onEnterOpenHABItem;
@property (strong, nonatomic) OpenHABItem* onLeaveOpenHABItem;

- (void)configureView;

@end

@implementation OpenHABBeaconNotificationDetailViewController

@synthesize items;

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.items = [[NSMutableArray alloc] init];
    self.openHABRootUrl = [[self appData] openHABRootUrl];
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    self.openHABUsername = [prefs valueForKey:@"username"];
    self.openHABPassword = [prefs valueForKey:@"password"];
    self.ignoreSSLCertificate = [prefs boolForKey:@"ignoreSSL"];
    
    
    _itemPicker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 50, 100, 150)];
    [_itemPicker setDataSource: self];
    [_itemPicker setDelegate: self];
    _itemPicker.showsSelectionIndicator = YES;
    
    UIToolbar *myToolbar = [[UIToolbar alloc] initWithFrame:
                            CGRectMake(0,0, 320, 44)];
    UIBarButtonItem *doneButton =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                  target:self action:@selector(inputAccessoryViewDidFinish)];
    //using default text field delegate method here, here you could call
    //myTextField.resignFirstResponder to dismiss the views
    [myToolbar setItems:[NSArray arrayWithObject: doneButton] animated:NO];
    
    _onEnterItem.inputAccessoryView = myToolbar;
    _onEnterItem.inputView = _itemPicker;
    _onLeaveItem.inputAccessoryView = myToolbar;
    _onLeaveItem.inputView = _itemPicker;
    
    UIBarButtonItem *rightBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(save:)];
    [self.navigationItem setRightBarButtonItem:rightBarButton];
    
    [self configureView];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self getPickerData];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Managing the detail item

- (void)setDetailItem:(id)newDetailItem
{
    if (_detailItem != newDetailItem)
    {
        _detailItem = newDetailItem;
        [self configureView];
    }
}

- (void)configureView
{
    if (_detailItem)
    {
        _beaconUUID.text = _detailItem.beaconUUID;
        
        if (_detailItem.beaconMajor)
        {
            _beaconMajor.text = [_detailItem.beaconMajor stringValue];
        }
        if (_detailItem.beaconMinor)
        {
            _beaconMinor.text = [_detailItem.beaconMinor stringValue];
        }
        
        _onEnterItem.text = _detailItem.onEnterItem.name;
        _onLeaveItem.text = _detailItem.onLeaveItem.name;
        _localNotification.on = _detailItem.localNotification;
        _descriptionTextfield.text = _detailItem.beaconDescription;
    }
    else
    {
        
        _localNotification.on = 0;
    }
    
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

- (void)getPickerData
{
    NSString *itemsUrlString = [NSString stringWithFormat:@"%@/rest/items?type=Switch", self.openHABRootUrl];
    NSURL *itemsUrl = [[NSURL alloc] initWithString:itemsUrlString];
    NSMutableURLRequest *itemsRequest = [NSMutableURLRequest requestWithURL:itemsUrl];
    [itemsRequest setAuthCredentials:self.openHABUsername :self.openHABPassword];
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:itemsRequest];
    AFRememberingSecurityPolicy *policy = [AFRememberingSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    operation.securityPolicy = policy;
    if (self.ignoreSSLCertificate)
    {
        NSLog(@"Warning - ignoring invalid certificates");
        operation.securityPolicy.allowInvalidCertificates = YES;
    }
    if ([self appData].openHABVersion == 2)
    {
        NSLog(@"Setting setializer to JSON");
        operation.responseSerializer = [AFJSONResponseSerializer serializer];
    }
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject)
     {
         NSData *response = (NSData*)responseObject;
         NSError *error;
         [items removeAllObjects];
         NSLog(@"Items response");
         // If we are talking to openHAB 1.X, talk XML
         if ([self appData].openHABVersion == 1) {
             NSLog(@"openHAB 1");
             NSLog(@"%@", [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
             GDataXMLDocument *doc = [[GDataXMLDocument alloc] initWithData:response error:&error];
             if (doc == nil) return;
             NSLog(@"%@", [doc.rootElement name]);
             if ([[doc.rootElement name] isEqual:@"items"])
             {
                 for (GDataXMLElement *element in [doc.rootElement elementsForName:@"item"])
                 {
                     OpenHABItem *item = [[OpenHABItem alloc] initWithXML:element];
                     [items addObject:item];
                 }
             } else {
                 return;
             }
             // Newer versions speak JSON!
         } else {
             NSLog(@"openHAB 2");
             if ([responseObject isKindOfClass:[NSArray class]]) {
                 NSLog(@"Response is array");
                 for (id itemsJson in responseObject)
                 {
                     OpenHABItem *item = [[OpenHABItem alloc] initWithDictionary:itemsJson];
                     [items addObject:item];
                 }
             } else {
                 // Something went wrong, we should have received an array
                 return;
             }
         }
         [_itemPicker reloadAllComponents];
     } failure:^(AFHTTPRequestOperation *operation, NSError *error){
         NSLog(@"Error:------>%@", [error description]);
         NSLog(@"error code %ld",(long)[operation.response statusCode]);
     }];
    [operation start];
}

- (OpenHABDataObject*)appData
{
    id<OpenHABAppDataDelegate> theDelegate = (id<OpenHABAppDataDelegate>) [UIApplication sharedApplication].delegate;
    return [theDelegate appData];
}


// The number of columns of data
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

// The number of rows of data
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return items.count;
}

// The data to return for the row and component (column) that's being passed in
- (NSString*)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    return ((OpenHABItem*)items[row]).name;
}

-(void) inputAccessoryViewDidFinish
{
    NSInteger row = [_itemPicker selectedRowInComponent:0];
    if (items.count > 0)
    {
        _textFieldResponder.text = ((OpenHABItem*)[items objectAtIndex:row]).name;
        if (_textFieldResponder == _onEnterItem)
        {
            _onEnterOpenHABItem = [items objectAtIndex:row];
        }
        else if (_textFieldResponder == _onLeaveItem)
        {
            _onLeaveOpenHABItem = [items objectAtIndex:row];
        }
    }
    [_textFieldResponder resignFirstResponder];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    if (textField == _onEnterItem || textField == _onLeaveItem)
    {
        _textFieldResponder = textField;
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField == _beaconUUID)
    {
        if (textField.text.length)
        {
            NSUUID* valid = [[NSUUID alloc] initWithUUIDString:textField.text];
            
            if (!valid)
            {
                UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Invalid UUID" message:@"Please check your UUID" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
                [alert show];
            }
        }
        else
        {
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Invalid UUID" message:@"UUID must not be empty!" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alert show];
        }
        [textField resignFirstResponder];
    }
}

#pragma mark - Button action

-(IBAction)save:(id)sender
{
    OpenHABBeaconNotification* beacon = [[OpenHABBeaconNotification alloc] init];
    
    beacon.beaconUUID = _beaconUUID.text;
    
    if (_beaconMajor.text.length)
    {
        beacon.beaconMajor = [NSNumber numberWithInteger:[_beaconMajor.text integerValue]];
    }
    
    if (_beaconMinor.text.length)
    {
        beacon.beaconMinor = [NSNumber numberWithInteger:[_beaconMinor.text integerValue]];
    }
    
    beacon.onEnterItem = _onEnterOpenHABItem;
    beacon.onLeaveItem = _onLeaveOpenHABItem;
    beacon.localNotification = _localNotification.on;
    beacon.beaconDescription = _descriptionTextfield.text;
    
    
    if (_detailItem)
    {
        [[[self appData] beaconLocations] removeBeacon:_detailItem];
    }
    
    [[[self appData] beaconLocations] addBeacon:beacon];
    
    [self.navigationController popViewControllerAnimated:YES];
    
}


@end