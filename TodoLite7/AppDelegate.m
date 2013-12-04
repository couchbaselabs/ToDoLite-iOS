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
#import "CBLSyncManager.h"
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
    
    // Configure sync and trigger it if the user is already logged in.
    [self setupCBLSync];

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

- (void) setupCBLSync {
    _cblSync = [[CBLSyncManager alloc] initSyncForDatabase:_database withURL:[NSURL URLWithString:kSyncUrl]];
    
    // Tell the Sync Manager to use Facebook for login.
    _cblSync.authenticator = [[CBLFacebookAuthenticator alloc] initWithAppID:kFBAppId];

    if (_cblSync.userID) {
        [_cblSync start];
    } else {
        // Application callback to create the user profile.
        [_cblSync beforeFirstSync:^(NSString *userID, NSDictionary *userData,  NSError **outError) {
            // This is a first run, setup the profile but don't save it yet.
            Profile *myProfile = [[Profile alloc] initCurrentUserProfileInDatabase:self.database withName:userData[@"name"] andUserID:userID];
            
            // Now tag all all lists created before the user logged in,
            // with the userID.
            
            [List updateAllListsInDatabase:self.database withOwner:myProfile error:outError];
            
            // Sync doesn't start until after this block completes, so
            // all this data will be tagged.
            if (!outError) {
                [myProfile save:outError];
            }
        }];
    }
    

}


- (void)loginAndSync: (void (^)())complete {
    if (_cblSync.userID) {
        complete();
        return;
    }
    [_cblSync beforeFirstSync:^(NSString *userID, NSDictionary *userData, NSError **outError) {
//        todo eventually we want to move to a more transparent model where the sync
        complete();
    }];
    [_cblSync start];
}

@end
