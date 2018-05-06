//
//  OpenHABAppDelegate.m
//  openHAB
//
//  Created by Victor Belov on 12/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "OpenHABAppDelegate.h"
#import "AFNetworking.h"
#import "NSData+HexString.h"
#import "TSMessage.h"
@import AVFoundation;
@import Firebase;
#import "AFRememberingSecurityPolicy.h"
#import "UIViewController+MMDrawerController.h"

@implementation OpenHABAppDelegate
@synthesize appData;

AVAudioPlayer *player;

- (id)init
{
    self.appData = [[OpenHABDataObject alloc] init];
    return [super init];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSLog(@"didFinishLaunchingWithOptions started");
    
    //init Firebase crash reporting
    [FIRApp configure];
    
//    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
//    manager.operationQueue.maxConcurrentOperationCount = 50;
    NSDictionary *appDefaults = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"CacheDataAgressively"];
    [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
    [self loadSettingsDefaults];
    [AFRememberingSecurityPolicy initializeCertificatesStore];
    // Notification registration now depends on iOS version (befor iOS8 and after it)
    // iOS 8 Notifications
    [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge) categories:nil]];
    [[UIApplication sharedApplication] registerForRemoteNotifications];
    
    NSLog(@"uniq id %@", [UIDevice currentDevice].identifierForVendor.UUIDString);
    NSLog(@"device name %@", [UIDevice currentDevice].name);
//    AudioSessionInitialize(NULL, NULL, nil , nil);
//    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error: nil];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient withOptions:AVAudioSessionCategoryOptionDuckOthers error:nil];
//    UInt32 doSetProperty = 1;
//    AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryMixWithOthers, sizeof(doSetProperty), &doSetProperty);
//    [[AVAudioSession sharedInstance] setActive: YES error: nil];
    NSLog(@"didFinishLaunchingWithOptions ended");
    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    // TODO: Pass this parameters to openHABViewController somehow to open specified sitemap/page and send specified command
    // Probably need to do this in a way compatible to Android app's URL
    NSLog(@"Calling Application Bundle ID: %@", sourceApplication);
    NSLog(@"URL scheme:%@", [url scheme]);
    NSLog(@"URL query: %@", [url query]);
    
    return YES;
}

- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken
{
	NSLog(@"My token is: %@", [deviceToken hexString]);
    NSDictionary *dataDict = @{
                               @"deviceToken": [deviceToken hexString],
                               @"deviceId": [UIDevice currentDevice].identifierForVendor.UUIDString,
                               @"deviceName": [UIDevice currentDevice].name,
                               };
    [[NSNotificationCenter defaultCenter] postNotificationName:@"apsRegistered" object:self userInfo:dataDict];
}

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error
{
	NSLog(@"Failed to get token, error: %@", error);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    NSLog(@"didReceiveRemoteNotification");
    if (application.applicationState == UIApplicationStateActive) {
        NSLog(@"App is active and got a remote notification");
        NSLog(@"%@", [userInfo valueForKey:@"aps"]);
        NSString *message = [[[userInfo valueForKey:@"aps"] valueForKey:@"alert"] valueForKey:@"body"];
        NSURL* soundPath = [[NSBundle mainBundle] URLForResource: @"ping" withExtension:@"wav"];
        NSLog(@"Sound path %@", soundPath);
        player = [[AVAudioPlayer alloc] initWithContentsOfURL:soundPath error:nil];
        if (player != nil) {
            player.numberOfLoops = 0;
            [player play];
        } else {
            NSLog(@"AVPlayer error");
        }
        
         [TSMessage showNotificationInViewController:((UINavigationController*)((MMDrawerController*)self.window.rootViewController).centerViewController).visibleViewController title:@"Notification" subtitle:message image:nil type:TSMessageNotificationTypeMessage duration:5.0 callback:nil buttonTitle:nil buttonCallback:nil atPosition:TSMessageNotificationPositionBottom canBeDismissedByUser:YES];
    }
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)loadSettingsDefaults
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    if (![prefs objectForKey:@"localUrl"])
        [prefs setValue:@"" forKey:@"localUrl"];
    if (![prefs objectForKey:@"remoteUrl"])
        [prefs setValue:@"" forKey:@"remoteUrl"];
    if (![prefs objectForKey:@"username"])
        [prefs setValue:@"" forKey:@"username"];
    if (![prefs objectForKey:@"password"])
        [prefs setValue:@"" forKey:@"password"];
    if (![prefs objectForKey:@"ignoreSSL"])
        [prefs setBool:NO forKey:@"ignoreSSL"];
    if (![prefs objectForKey:@"demomode"])
        [prefs setBool:YES forKey:@"demomode"];
    if (![prefs objectForKey:@"idleOff"])
        [prefs setBool:NO forKey:@"idleOff"];
}

@end
