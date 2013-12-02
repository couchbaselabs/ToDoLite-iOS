//
//  AppDelegate.h
//  TodoLite7
//
//  Created by Chris Anderson on 11/14/13.
//  Copyright (c) 2013 Chris Anderson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Accounts/Accounts.h>
#import <CouchbaseLite/CouchbaseLite.h>
#import "CBLFacebookSync.h"


@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) CBLDatabase *database;
@property (strong, nonatomic) CBLFacebookSync *cblSync;

- (void)loginAndSync: (void (^)())complete;

@end
