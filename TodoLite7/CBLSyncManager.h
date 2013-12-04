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

@class CBLSyncManager;

#pragma mark - Authenticators


// base Authenticator, you can inherit from this to
// create a custom Authenticator
//@interface CBLSyncAuthenticator : NSObject
//
//@end

// example Facebook Authenticator
@interface CBLFacebookAuthenticator : NSObject
@property (readwrite) CBLSyncManager *syncManager;
@property (readonly) NSString *facebookAppID;
- (instancetype) initWithAppID:(NSString *)facebookAppID;

-(void) getCredentials: (void (^)(NSString *userID, NSDictionary *userData))block;
-(void) registerCredentialsWithReplications: (NSArray *)repls;
@end

#pragma mark - CBLSyncManager

@interface CBLSyncManager : NSObject

- (instancetype) initSyncForDatabase:(CBLDatabase*)database
                             withURL:(NSURL*)remoteURL;

- (instancetype) initSyncForDatabase:(CBLDatabase*)database
                      withURL:(NSURL*)remoteURL
                       asUser:(NSString*)userID;

@property (readonly) CBLDatabase *database;
@property (readonly) NSString *userID;
@property (readonly) NSURL *remoteURL;
@property (readwrite, nonatomic) CBLFacebookAuthenticator *authenticator;

//// setup the facebook authenticator
- (void)setAuthenticator:(CBLFacebookAuthenticator *)authenticator;

//- (void)useFacebookAppID: (NSString *)myAppID;

// register a callback for when we discover the user info
- (void)beforeFirstSync: (void (^)(NSString *userID, NSDictionary *userData, NSError **outError))block;

// register a callback for after the sync begins making progress
- (void)onSyncConnected: (void (^)())block;

// register a callback in case of errors
// should make errors that can be resolved by refreshing the login
// token clearly distinct from errors the user can't do much about
//- (void)onSyncError: (void (^)())block;

- (void)start;

@end

