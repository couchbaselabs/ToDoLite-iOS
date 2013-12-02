//
//  CBLSocialSync.h
//  TodoLite7
//
//  Created by Chris Anderson on 11/16/13.
//  Copyright (c) 2013 Chris Anderson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Accounts/Accounts.h>
#import <Social/Social.h>
#import <CouchbaseLite/CouchbaseLite.h>

@interface CBLFacebookSync : NSObject

- (instancetype) initSyncForDatabase:(CBLDatabase*)database
                             withURL:(NSURL*)remoteURL
                  usingFacebookAppID:(NSString*)facebookAppID;

- (instancetype) initSyncForDatabase:(CBLDatabase*)database
                      withURL:(NSURL*)remoteURL
                       asUser:(NSString*)userID
           usingFacebookAppID:(NSString*)facebookAppID;

@property (readonly) CBLDatabase *database;
@property (readonly) NSString *userID;
@property (readonly) NSURL *remoteURL;
@property (readonly) NSString *facebookAppID;

// register a callback for when we discover the user info
- (void)onUserData: (void (^)(NSString *userID, NSDictionary *userData))block;

// register a callback for after we have triggered the sync
- (void)onSyncStarted: (void (^)())block;

// register a callback in case of errors
// should make errors that can be resolved by refreshing the login
// token clearly distinct from errors the user can't do much about
//- (void)onSyncError: (void (^)())block;

- (void)start;

@end

