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

// Sync Gateway
#define kSyncGatewayUrl @"http://10.17.3.228:4984/todos"


@interface AppDelegate () <UIAlertViewDelegate>

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [CBLManager enableLogging:@"Sync"];

    [self createDatabase];

    _currentUserId = @"pasin";

    NSError *error;
    Profile *userProfile = [Profile profileInDatabase:_database
                                         forNewUserId:_currentUserId name:@"Pasin"];
    [userProfile save: &error];

    NSLog(@"User Profile %@", userProfile.document.properties);

    [self startReplications];

    return YES;
}

- (void)createDatabase {
    NSError *error;
    _database = [[CBLManager sharedInstance] databaseNamed:@"todosapp" error:&error];
}

- (void)startReplications {
    NSURL *url = [NSURL URLWithString:kSyncGatewayUrl];

    CBLReplication *push = [self.database createPushReplication:url];
    push.continuous = YES;
    push.authenticator = [CBLAuthenticator basicAuthenticatorWithName:@"pasin" password:@"123"];

    CBLReplication *pull = [self.database createPullReplication:url];
    pull.continuous = YES;
    pull.authenticator = [CBLAuthenticator basicAuthenticatorWithName:@"pasin" password:@"123"];

    [pull start];
    [push start];
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
