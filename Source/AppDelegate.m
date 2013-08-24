//
//  AppDelegate.m
//  Couchbase Lists
//
//  Created by Jan Lehnardt on 27/11/2010.
//  Copyright 2011 Couchbase, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not
// use this file except in compliance with the License. You may obtain a copy of
// the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations under
// the License.
//

#import "AppDelegate.h"
#import "ListController.h"
#import "MasterController.h"

#import <Couchbaselite/CouchbaseLite.h>


// The name of the database the app will use.
#define kDatabaseName @"todo"

// The default remote database URL to sync with, if the user hasn't set a different one as a pref.
//#define kDefaultSyncDbURL @"http://couchbase.iriscouch.com/grocery-sync"

// Define this to use a server at a specific URL, instead of the embedded Couchbase Lists.
// This can be useful for debugging, since you can use the admin console (futon) to inspect
// or modify the database contents.
//#define USE_REMOTE_SERVER @"http://localhost:5984/"


@implementation AppDelegate


// Override point for customization after application launch.
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"------ application:didFinishLaunchingWithOptions:");
    gAppDelegate = self;
    
#ifdef kDefaultSyncDbURL
    // Register the default value of the pref for the remote database URL to sync with:
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *appdefaults = [NSDictionary dictionaryWithObject:kDefaultSyncDbURL
                                                            forKey:@"syncpoint"];
    [defaults registerDefaults:appdefaults];
    [defaults synchronize];
#endif
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    // Get or create the database.
    NSError* error;
    self.database = [[CBLManager sharedInstance] createDatabaseNamed: kDatabaseName
                                                               error: &error];
    if (!self.database)
        [self showAlert: @"Couldn't open database" error: error fatal: YES];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        // iPhone UI:
        MasterController *master = [[MasterController alloc] initWithNibName:@"MasterController_iPhone" bundle:nil];
        [master useDatabase: _database];
        self.navigationController = [[UINavigationController alloc] initWithRootViewController:master];
        self.window.rootViewController = self.navigationController;
    } else {
        // iPad UI:
        MasterController *master = [[MasterController alloc] initWithNibName:@"MasterController_iPad" bundle:nil];
        [master useDatabase: _database];
        UINavigationController *masterNavigationController = [[UINavigationController alloc] initWithRootViewController:master];

        ListController *listController = [[ListController alloc] initWithNibName:@"ListController_iPad" bundle:nil];
        [listController useDatabase: _database];
        UINavigationController *detailNavigationController = [[UINavigationController alloc] initWithRootViewController:listController];

        self.navigationController = detailNavigationController;

    	master.listController = listController;

        self.splitViewController = [[UISplitViewController alloc] init];
        self.splitViewController.delegate = listController;
        self.splitViewController.viewControllers = @[masterNavigationController, detailNavigationController];

        self.window.rootViewController = self.splitViewController;
    }

    [self.window makeKeyAndVisible];
    return YES;
}


// Display an error alert, without blocking.
// If 'fatal' is true, the app will quit when it's pressed.
- (void)showAlert: (NSString*)message error: (NSError*)error fatal: (BOOL)fatal {
    if (error) {
        message = [NSString stringWithFormat: @"%@\n\n%@", message, error.localizedDescription];
    }
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle: (fatal ? @"Fatal Error" : @"Error")
                                                    message: message
                                                   delegate: (fatal ? self : nil)
                                          cancelButtonTitle: (fatal ? @"Quit" : @"Sorry")
                                          otherButtonTitles: nil];
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    exit(0);
}




@end
