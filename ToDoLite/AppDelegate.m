//
//  AppDelegate.m
//  ToDoLite
//
//  Created by Pasin Suriyentrakorn on 10/11/14.
//  Copyright (c) 2014 Pasin Suriyentrakorn. All rights reserved.
//

#import "AppDelegate.h"
#import "DetailViewController.h"
#import "LoginViewController.h"
#import "Profile.h"
#import <CouchbaseLite/CouchbaseLite.h>

// Sync Gateway
#define kSyncGatewayUrl @"http://localhost:4984/todos"

@interface AppDelegate () <UIAlertViewDelegate>

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSError *error;
    [CBLManager enableLogging:@"Sync"];
    [CBLManager enableLogging:@"SyncVerbose"];
    
    
    _currentUserId = @"bewarned";
    [self createDatabase];
    
    
    Profile *profile = [Profile profileInDatabase:_database forNewUserId:_currentUserId name:@"Byron"];
    NSLog(@"The profile object was saved %@", [[profile document] properties]);
    if (![profile save:&error]) {
        NSLog(@"Could not save profile because: %@", error);
    }
    [self startReplications];
    return YES;
}

- (void)startReplications {
    CBLReplication *puller = [self.database createPullReplication:[NSURL URLWithString:kSyncGatewayUrl]];
    puller.continuous = YES;
    [puller start];
    CBLReplication *pusher = [self.database createPushReplication:[NSURL URLWithString:kSyncGatewayUrl]];
    pusher.continuous = YES;
    [pusher start];
}
- (void)createDatabase {
    NSError *error;
    _database = [[CBLManager sharedInstance] databaseNamed:@"todoapps" error:&error];
    if (!_database) {
        NSLog(@"error creating database: %@", error);
    }
}

#pragma mark - Message

- (void)showMessage:(NSString *)text withTitle:(NSString *)title {
    [[[UIAlertView alloc] initWithTitle:title
                                message:text
                               delegate:nil
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
}

@end
