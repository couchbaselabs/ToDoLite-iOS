//
//  AppDelegate.m
//  TodoLite7
//
//  Created by Chris Anderson on 11/14/13.
//  Copyright (c) 2013 Chris Anderson. All rights reserved.
//

#import "AppDelegate.h"
#import <Social/Social.h>
#import <CouchbaseLite/CouchbaseLite.h>
#import "CBLFacebookSync.h"
#import "List.h"
#import "Task.h"
#import "Profile.h"

#define kSyncUrl @"http://sync.couchbasecloud.com:4984/todos4"
#define kFBAppId @"501518809925546"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
        UINavigationController *navigationController = [splitViewController.viewControllers lastObject];
        splitViewController.delegate = (id)navigationController.topViewController;
    }
    CBLManager *manager = [CBLManager sharedInstance];
    NSError *error;
    self.database = [manager databaseNamed: @"todos" error: &error];
    if (error) {
        NSLog(@"error getting database %@",error);
        exit(-1);
    }
//    todo validation should go in the model?
    [[self.database modelFactory] registerClass: [List class] forDocumentType: @"list"];
    [[self.database modelFactory] registerClass: [Task class] forDocumentType: @"item"];
    
//    NSString* userID = [[NSUserDefaults standardUserDefaults] objectForKey: @"CBLFBUserID"];

    [self syncIfLoggedIn];

    return YES;
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

#pragma mark - Sync

- (void) syncIfLoggedIn {
    if (_cblSync) return;
//    this one should not set cblsync unless the user is logged in
    CBLFacebookSync *maybe_cblSync = [[CBLFacebookSync alloc] initSyncForDatabase:_database withURL:[NSURL URLWithString:kSyncUrl] usingFacebookAppID:kFBAppId];
    if (maybe_cblSync.userID) {
        _cblSync = maybe_cblSync;
        [_cblSync start];
    }
}

- (void)loginAndSync: (void (^)())complete {
    if (_cblSync && _cblSync.userID) {
        complete();
        return;
    }
    _cblSync = [[CBLFacebookSync alloc] initSyncForDatabase:_database withURL:[NSURL URLWithString:kSyncUrl] usingFacebookAppID:kFBAppId];
    [_cblSync onUserData:^(NSString *userID, NSDictionary *userData) {
        Profile *myProfile = [[Profile alloc] initCurrentUserProfileInDatabase:self.database withName:userData[@"name"] andUserId:userID];
        NSError *e;
        [List updateAllListsInDatabase:self.database withOwner:myProfile error:&e];
        if (!e) {
            [myProfile save:&e];
        }
    }];
    [_cblSync onSyncStarted:complete];
    [_cblSync start];
}

@end
