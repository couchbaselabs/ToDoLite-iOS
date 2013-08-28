//
//  AppDelegate.m
//  ToDoLite
//
//  Created by Jan Lehnardt on 27/11/2010.
//  Copyright 2010-2013 Couchbase, Inc.
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


AppDelegate* gAppDelegate;
BOOL gRunningOnIPad;


// The name of the database the app will use.
#define kDatabaseName @"todo"

// The default remote database URL to sync with, if the user hasn't set a different one as a pref.
//#define kDefaultSyncDbURL @"http://sync.couchbasecloud.com:4984/todos/"


@implementation AppDelegate
{
    UISplitViewController* _splitViewController;
    UINavigationController* _navigationController;
    NSArray* _replications;
}


// Override point for customization after application launch.
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"------ application:didFinishLaunchingWithOptions:");
    gAppDelegate = self;
    gRunningOnIPad = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
    
#ifdef kDefaultSyncDbURL
    // Register the default value of the pref for the remote database URL to sync with:
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *appdefaults = [NSDictionary dictionaryWithObject:kDefaultSyncDbURL
                                                            forKey:kPrefServerDB];
    [defaults registerDefaults:appdefaults];
    [defaults synchronize];
#endif
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    // Get or create the database.
    NSError* error;
    _database = [[CBLManager sharedInstance] createDatabaseNamed: kDatabaseName
                                                               error: &error];
    if (!_database)
        [self showAlert: @"Couldn't open database" error: error fatal: YES];
    
    if (!gRunningOnIPad) {
        // iPhone UI:
        MasterController *master = [[MasterController alloc] initWithDatabase: _database];
        _navigationController = [[UINavigationController alloc] initWithRootViewController:master];
        self.window.rootViewController = _navigationController;
    } else {
        // iPad UI:
        MasterController *master = [[MasterController alloc] initWithDatabase: _database];
        UINavigationController *masterNavigationController = [[UINavigationController alloc] initWithRootViewController:master];

        ListController *listController = [[ListController alloc] initWithDatabase: _database];
        UINavigationController *detailNavigationController = [[UINavigationController alloc] initWithRootViewController:listController];

        _navigationController = detailNavigationController;

    	master.listController = listController;

        _splitViewController = [[UISplitViewController alloc] init];
        _splitViewController.delegate = listController;
        _splitViewController.viewControllers = @[masterNavigationController, detailNavigationController];

        self.window.rootViewController = _splitViewController;
    }

    [self.window makeKeyAndVisible];

    if (![self observeSync]) {
#ifdef kDefaultSyncDbURL
        // If no replication exists, create one with the default server:
        [self setReplicationURL: [NSURL URLWithString: kDefaultSyncDbURL]];
#endif
    }

    return YES;
}


#pragma mark - ALERTS:


// Displays an error alert, without blocking.
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


#pragma mark - SYNC:


// Gets the current replication URL.
- (NSURL*) syncURL {
    if (_replications.count == 0)
        return nil;
    return [_replications[0] remoteURL];
}


// Tells the database what URL to replicate with, and registers for observation
- (void) setSyncURL: (NSURL*)url {
    [_database replicateWithURL: url exclusively: YES];
    [self observeSync];
}


#if 0
// Opens a ConfigViewController (asynchronously)
- (void) configureSync {
    ConfigViewController* controller = [[ConfigViewController alloc] initWithURL: self.syncURL];
    [_navigationController pushViewController: controller animated: YES];
    // The controller will set my .syncURL property when the user enters a URL.
}
#endif


// Registers NSNotification observers on the current replications
- (BOOL) observeSync {
    NSNotificationCenter* nctr = [NSNotificationCenter defaultCenter];
    [nctr removeObserver: self name: kCBLReplicationChangeNotification object: nil];
    _replications = [_database allReplications];

    if (_replications.count == 0)
        return NO;

    for (CBLReplication* repl in _replications) {
        [nctr addObserver: self selector: @selector(replicatorChanged:)
                     name: kCBLReplicationChangeNotification object: repl];
    }
    return YES;
}


// Called when a replication's state changes
- (void) replicatorChanged: (NSNotificationCenter*)n {
    // First collect the aggregate state of both (pull+push) replications:
    BOOL active = NO;
    unsigned completed = 0, total = 0;
    for (CBLReplication* repl in _replications) {
        if (repl.mode == kCBLReplicationActive) {
            completed += repl.completed;
            total += repl.total;
            active = YES;
        }
    }
    // Now update the UI:
    NSLog(@"SYNC progress: %u / %u", completed, total);
    //_progress.progress = completed / (float)MAX(total, 1u);
    [UIApplication sharedApplication].networkActivityIndicatorVisible = active;
}


@end
