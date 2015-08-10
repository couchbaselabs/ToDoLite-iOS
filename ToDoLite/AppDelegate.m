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
#import <CouchbaseLite/CBLAuthenticator.h>

// Sync Gateway
#define kSyncGatewayUrl @"http://10.21.52.95:4984/todos"


@interface AppDelegate () <UIAlertViewDelegate>

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [CBLManager enableLogging:@"Sync"];

    [self createDatabase];

    _currentUserId = @"pasin";

    NSError *error;
    NSArray *profiles = @[
                        @{ @"username": @"pasin", @"name": @"Pasin"},
                        @{ @"username": @"vilma", @"name": @"Vilma"},
                        @{ @"username": @"levi", @"name": @"Levi"}
                        ];
    for (NSDictionary *profile in profiles) {
        NSString *name = profile[@"name"];
        NSString *userName = profile[@"username"];
        
        Profile *userProfile = [Profile profileInDatabase:_database
                                             forNewUserId:userName name:name];
        [userProfile save: &error];
        
        NSLog(@"User Profile %@", userProfile.document.properties);
    }

    [self startReplications];

    [self addShakeHandler:application];
    
    return YES;
}

- (void)createDatabase {
    NSError *error;
    _database = [[CBLManager sharedInstance] databaseNamed:@"todosapp" error:&error];
    [_database setFilterNamed:@"ignoreShakes" asBlock:FILTERBLOCK({
        return ![revision[@"type"] isEqualToString: @"shake"];
    })];
}

- (void)startReplications {
    NSURL *url = [NSURL URLWithString:kSyncGatewayUrl];

    CBLReplication *push = [self.database createPushReplication:url];
    push.continuous = YES;
    push.authenticator = [CBLAuthenticator basicAuthenticatorWithName:@"pasin" password:@"123"];
    //push.filter = @"ignoreShakes";
    
    CBLReplication *pull = [self.database createPullReplication:url];
    pull.continuous = YES;
    pull.authenticator = [CBLAuthenticator basicAuthenticatorWithName:@"pasin" password:@"123"];

    [pull start];
    [push start];
}

#pragma mark - Shake

- (void)addShakeHandler:(UIApplication *)application {
    [application setApplicationSupportsShakeToEdit:YES];
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
