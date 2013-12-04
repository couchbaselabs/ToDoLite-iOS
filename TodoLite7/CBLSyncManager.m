//
//  CBLSocialSync.m
//  TodoLite7
//
//  Created by Chris Anderson on 11/16/13.
//  Copyright (c) 2013 Chris Anderson. All rights reserved.
//

#import "CBLSyncManager.h"

#define kCBLPrefKeyUserID @"CBLFBUserID"


@interface CBLSyncManager () {
    CBLReplication *pull;
    CBLReplication *push;
    NSArray *beforeSyncBlocks;
    NSArray *onSyncStartedBlocks;
}
@end

@implementation CBLSyncManager

- (instancetype) initSyncForDatabase:(CBLDatabase*)database
                             withURL:(NSURL*)remoteURL {
    NSString* userID = [[NSUserDefaults standardUserDefaults] objectForKey: kCBLPrefKeyUserID];
    self = [self initSyncForDatabase:database withURL:remoteURL asUser:userID];
    if (self) {
        [self beforeFirstSync:^(NSString *newUserId, NSDictionary *userData, NSError **outError) {
            [[NSUserDefaults standardUserDefaults] setObject: newUserId forKey: kCBLPrefKeyUserID];
        }];
    }
    return self;
}

- (instancetype) initSyncForDatabase:(CBLDatabase*)database
                      withURL:(NSURL*)remoteURL
                       asUser:(NSString*)userID {
    self = [super init];
    if (self) {
        _database = database;
        _userID = userID;
        _remoteURL = remoteURL;
        beforeSyncBlocks = @[];
        onSyncStartedBlocks = @[];
    }
    return self;
}

#pragma mark - Public Instance API

- (void) start {
    if (!_userID) {
        [self setupNewUser: ^(){
            [self launchSync];
        }];
    } else {
        [self launchSync];
    }
}

//- (void)useFacebookAppID: (NSString *)myAppID {
//    _authenticator = [[CBLFacebookAuthenticator alloc]initWithAppID: myAppID];
//}


- (void)beforeFirstSync: (void (^)(NSString *userID, NSDictionary *userData, NSError **outError))block {
    beforeSyncBlocks = [beforeSyncBlocks arrayByAddingObject:block];
}

- (void)onSyncConnected: (void (^)())block {
    onSyncStartedBlocks = [onSyncStartedBlocks arrayByAddingObject:block];
}

- (void)setAuthenticator:(NSObject<CBLSyncAuthenticator> *)authenticator {
    _authenticator = authenticator;
    _authenticator.syncManager = self;
}


#pragma mark - Callbacks

- (NSError*) runBeforeSyncStartWithUserID: (NSString *)userID andUserData: (NSDictionary *)userData {
    void (^beforeSyncBlock)(NSString *userID, NSDictionary *userData, NSError **outError);
    NSError *error;
    for (beforeSyncBlock in beforeSyncBlocks) {
        if (error) return error;
        beforeSyncBlock(userID, userData, &error);
    }
    return error;
}

#pragma mark - Sync related

- (void) launchSync {
    NSLog(@"launch Sync");

    [self defineSync];
    

    [self startSync];
    
//    void (^onSyncStartedBlock)();
//    for (onSyncStartedBlock in onSyncStartedBlocks) {
//        onSyncStartedBlock();
//    }
    
}

- (void)defineSync
{
    pull = [_database replicationFromURL:_remoteURL];
    pull.continuous = YES;
//    pull.persistent = YES;
    
    push = [_database replicationToURL:_remoteURL];
    push.continuous = YES;
//    push.persistent = YES;
    
    [_authenticator registerCredentialsWithReplications: @[pull, push]];
}


- (void)startSync {
    //    todo listen for sync errors
    NSLog(@"startSync");
    [pull start];
    [push start];
}

#pragma mark - User ID related

- (void) setupNewUser:(void (^)())complete {
    if (_userID) return;
    [_authenticator getCredentials: ^(NSString *userID, NSDictionary *userData){
        if (_userID) return;
        // Give the app a chance to tag documents with userID before sync starts
        NSError *error = [self runBeforeSyncStartWithUserID: userID andUserData: userData];
        if (error) {
            NSLog(@"error preparing for sync %@", error);
        } else {
            _userID = userID;
            complete();
        }
    }];
}


@end

@implementation CBLFacebookAuthenticator

@synthesize syncManager=_syncManager;

- (instancetype) initWithAppID:(NSString *)appID {
    self = [super init];
    if (self) {
        _facebookAppID = appID;
    }
    return self;
}

-(void) getCredentials: (void (^)(NSString *userID, NSDictionary *userData))block {
    
    [self getFaceBookAccessToken:^(NSString* accessToken, ACAccount* fbAccount){
        
        [self getFacebookUserInfoWithAccessToken:accessToken facebookAccount: fbAccount onCompletion: ^(NSDictionary* userData){
            
            NSString *userID = userData[@"email"];
            
            // Store the access_token for later.
            [[NSUserDefaults standardUserDefaults] setObject: accessToken forKey: [self accessTokenKeyForUserID:userID]];
            
            block(userID, userData);
            
        }];
    }];
}

-(void) registerCredentialsWithReplications: (NSArray *)repls {
    NSString* userID = _syncManager.userID;
    NSString* accessToken = [[NSUserDefaults standardUserDefaults] objectForKey: [self accessTokenKeyForUserID:userID]];
    if (!userID) return;
    for (CBLReplication * repl in repls) {
        NSLog(@"repl %@", repl);
        [repl setFacebookEmailAddress:userID];
        [repl registerFacebookToken:accessToken forEmailAddress:userID];
    }
}

#pragma mark - Facebook API related

- (void)getFacebookUserInfoWithAccessToken: (NSString*)accessToken facebookAccount:(ACAccount *)fbAccount onCompletion: (void (^)(NSDictionary* userData))complete
{
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeFacebook
                                            requestMethod:SLRequestMethodGET
                                                      URL:[NSURL URLWithString:@"https://graph.facebook.com/me"]
                                               parameters:nil];
    request.account = fbAccount;
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

- (NSString*) accessTokenKeyForUserID: (NSString *)userID {
    return [@"CBLFBAT-" stringByAppendingString: userID];
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
             // Get the access token
             ACAccountCredential *fbCredential = [fbAccount credential];
             NSString *accessToken = [fbCredential oauthToken];
             complete(accessToken, fbAccount);
         } else {
             //Fail gracefully...
             NSLog(@"error getting permission %@",e);
             //             todo should alert to tell the user to go to settings
         }
     }];
}


@end
