//
//  CBLSocialSync.m
//  TodoLite7
//
//  Created by Chris Anderson on 11/16/13.
//  Copyright (c) 2013 Chris Anderson. All rights reserved.
//

#import "CBLFacebookSync.h"

#define kCBLPrefKeyUserID @"CBLFBUserID"


@interface CBLFacebookSync () {
    CBLReplication *pull;
    CBLReplication *push;
    NSArray *onUserDataBlocks;
    NSArray *onSyncStartedBlocks;
}
@end

@implementation CBLFacebookSync

- (instancetype) initSyncForDatabase:(CBLDatabase*)database
                             withURL:(NSURL*)remoteURL
                  usingFacebookAppID:(NSString*)facebookAppID {
    NSString* userID = [[NSUserDefaults standardUserDefaults] objectForKey: kCBLPrefKeyUserID];
    self = [self initSyncForDatabase:database withURL:remoteURL asUser:userID usingFacebookAppID:facebookAppID];
    if (self) {
        [self onUserData:^(NSString *newUserId, NSDictionary *userData) {
            [[NSUserDefaults standardUserDefaults] setObject: newUserId forKey: kCBLPrefKeyUserID];
        }];
    }
    return self;
}

- (instancetype) initSyncForDatabase:(CBLDatabase*)database
                      withURL:(NSURL*)remoteURL
                       asUser:(NSString*)userID
           usingFacebookAppID:(NSString*)facebookAppID {
    self = [super init];
    if (self) {
        _database = database;
        _userID = userID;
        _remoteURL = remoteURL;
        _facebookAppID = facebookAppID;
        onUserDataBlocks = @[];
        onSyncStartedBlocks = @[];
    }
    return self;
}

#pragma mark - Public Instance API

- (void)onUserData: (void (^)(NSString *userID, NSDictionary *userData))block {
    onUserDataBlocks = [onUserDataBlocks arrayByAddingObject:block];
}

- (void)onSyncStarted: (void (^)())block {
    onSyncStartedBlocks = [onSyncStartedBlocks arrayByAddingObject:block];
}

- (void) start {
    if (!_userID) {
        [self setupNewUser: ^(){
            [self launchSync];
        }];
    } else {
        [self launchSync];
    }
}

#pragma mark - Sync related

- (void) launchSync {
    NSLog(@"launch Sync");

    [self defineSync];
    [self registerFacebookAccessTokenAndUser];
    [self startSync];
    
    void (^onSyncStartedBlock)();
    for (onSyncStartedBlock in onSyncStartedBlocks) {
        onSyncStartedBlock();
    }
    
}

- (void)defineSync
{
    pull = [_database replicationFromURL:_remoteURL];
    pull.continuous = YES;
//    pull.persistent = YES;
    
    push = [_database replicationToURL:_remoteURL];
    push.continuous = YES;
//    push.persistent = YES;
}

- (void)registerFacebookAccessTokenAndUser
{
    NSString* accessToken = [[NSUserDefaults standardUserDefaults] objectForKey: [self accessTokenKey]];
    
    [pull setFacebookEmailAddress:_userID];
    [pull registerFacebookToken:accessToken forEmailAddress:_userID];

    [push setFacebookEmailAddress:_userID];
    [push registerFacebookToken:accessToken forEmailAddress:_userID];
}

- (void)startSync {
    //    todo listen for sync errors
    NSLog(@"startSync");
    [pull start];
    [push start];
}

- (NSString*) accessTokenKey {
    return _userID ? [@"CBLFBAT-" stringByAppendingString:_userID] : nil;
}

#pragma mark - User ID related

- (void) setupNewUser:(void (^)())block; {
    [self getFaceBookAccessToken:^(NSString* accessToken, ACAccount* fbAccount){
        [self getFacebookUserInfoWithAccessToken:accessToken facebookAccount: fbAccount onCompletion: ^(NSDictionary* userData){
            if (!_userID) {
                _userID = userData[@"email"];
            }
            [[NSUserDefaults standardUserDefaults] setObject: accessToken forKey: [self accessTokenKey]];
            void (^onUserDataBlock)(NSString *userID, NSDictionary *userData);
            for (onUserDataBlock in onUserDataBlocks) {
                onUserDataBlock(userData[@"email"], userData);
            }
            block();
        }];
    }];
}

- (void)getFacebookUserInfoWithAccessToken: (NSString*)accessToken facebookAccount:(ACAccount *)fbAccount onCompletion: (void (^)(NSDictionary* userData))complete
{
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeFacebook
                                            requestMethod:SLRequestMethodGET
                                                      URL:[NSURL URLWithString:@"https://graph.facebook.com/me"]
                                               parameters:nil];
    request.account = fbAccount; // This is the _account from your code
    [request performRequestWithHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error == nil && ((NSHTTPURLResponse *)response).statusCode == 200) {
            NSError *deserializationError;
            NSDictionary *userData = [NSJSONSerialization JSONObjectWithData:data options:0 error:&deserializationError];
            
            if (userData != nil && deserializationError == nil) {
                complete(userData);
            }
        }
    }];
}

- (void)getFaceBookAccessToken: (void (^)(NSString* accessToken, ACAccount* fbAccount))complete
{
    ACAccountStore *accountStore = [[ACAccountStore alloc]init];
    
    
    ACAccountType *FBaccountType= [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
    
    NSDictionary *dictFB = [NSDictionary dictionaryWithObjectsAndKeys:_facebookAppID, ACFacebookAppIdKey, @[@"email"], ACFacebookPermissionsKey, nil];
    
    
    [accountStore requestAccessToAccountsWithType:FBaccountType options:dictFB completion:
     ^(BOOL granted, NSError *e) {
         if (granted) {
             NSArray *accounts = [accountStore accountsWithAccountType:FBaccountType];
             ACAccount *fbAccount = [accounts lastObject];
             //it will always be the last object with single sign on
             NSString *name = [fbAccount username];
             // Get the access token, could be used in other scenarios
             ACAccountCredential *fbCredential = [fbAccount credential];
             NSString *accessToken = [fbCredential oauthToken];
             NSLog(@"Facebook Name %@ Access Token: %@", name, accessToken);
             complete(accessToken, fbAccount);
         } else {
             //Fail gracefully...
             NSLog(@"error getting permission %@",e);
             //             todo should alert to tell the user to go to settings
         }
     }];
}

@end
