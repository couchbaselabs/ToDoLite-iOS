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
    NSError *lastAuthError;
}
@end

@implementation CBLSyncManager

- (instancetype)initSyncForDatabase:(CBLDatabase *)database withURL:(NSURL *)remoteURL {
    NSString *userID = [[NSUserDefaults standardUserDefaults] objectForKey:kCBLPrefKeyUserID];
    self = [self initSyncForDatabase:database withURL:remoteURL asUser:userID];
    if (self) {
        [self beforeFirstSync:^(NSString *newUserId, NSDictionary *userData, NSError **outError) {
            [[NSUserDefaults standardUserDefaults] setObject: newUserId forKey: kCBLPrefKeyUserID];
        }];
    }
    return self;
}

- (instancetype)initSyncForDatabase:(CBLDatabase *)database withURL:(NSURL *)remoteURL asUser:(NSString *)userID {
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
        [self setupNewUser:^(){
            [self launchSync];
        }];
    } else {
        [self launchSync];
    }
}


- (void)beforeFirstSync:(void (^)(NSString *userID, NSDictionary *userData, NSError **outError))block {
    beforeSyncBlocks = [beforeSyncBlocks arrayByAddingObject:block];
}

- (void)onSyncConnected:(void (^)())block {
    onSyncStartedBlocks = [onSyncStartedBlocks arrayByAddingObject:block];
}

- (void)setAuthenticator:(NSObject<CBLSyncAuthenticator> *)authenticator {
    _authenticator = authenticator;
    _authenticator.syncManager = self;
    if (lastAuthError) {
        [self runAuthenticator];
    }
}

#pragma mark - Callbacks

- (NSError *)runBeforeSyncStartWithUserID: (NSString *)userID andUserData: (NSDictionary *)userData {
    void (^beforeSyncBlock)(NSString *userID, NSDictionary *userData, NSError **outError);
    NSError *error;
    for (beforeSyncBlock in beforeSyncBlocks) {
        if (error) return error;
        beforeSyncBlock(userID, userData, &error);
    }
    return error;
}

#pragma mark - Sync related

- (void)runAuthenticator {
    [_authenticator getCredentials:^(NSString *newUserID, NSDictionary *userData) {
        // TODO: this should call our onSyncAuthError callback
        NSAssert2([newUserID isEqualToString:_userID], @"can't change userID from %@ to %@, need to reinstall", _userID,  newUserID);
        [self restartSync];
    }];
}

- (void)launchSync {
    [self defineSync];
    
    if (lastAuthError) {
        NSAssert(_authenticator, @"autnenacr");
        [self runAuthenticator];
    } else {
        [self restartSync];
    }
}

- (void)defineSync {
    pull = [_database createPullReplication:_remoteURL];
    pull.continuous = YES;
    
    push = [_database createPushReplication:_remoteURL];
    push.continuous = YES;
    
    [self listenForReplicationEvents: push];
    [self listenForReplicationEvents: pull];
    
    [_authenticator registerCredentialsWithReplications: @[pull, push]];
}

- (void)listenForReplicationEvents:(CBLReplication*)repl {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(replicationProgress:)
                                                 name:kCBLReplicationChangeNotification
                                               object:repl];
}


- (void)replicationProgress:(NSNotificationCenter*)n {
    bool active = false;
    unsigned completed = 0, total = 0;
    CBLReplicationStatus status = kCBLReplicationStopped;
    NSError *error = nil;
    for (CBLReplication *repl in @[pull, push]) {
        status = MAX(status, repl.status);
        if (!error)
            error = repl.lastError;
        if (repl.status == kCBLReplicationActive) {
            active = true;
            completed += repl.completedChangesCount;
            total += repl.changesCount;
        }
    }
    
    if (error != _error && error.code == 401) {
        // Auth needed (or auth is incorrect), ask the _authenticator to get new credentials.
        if (!_authenticator) {
            // sync hasn't been triggered yet
            // we'll retry when sync is triggered
            lastAuthError = error;
            return;
        }
        
        [self runAuthenticator];

    }
    
    if (active != _active || completed != _completed || total != _total || status != _status
        || error != _error) {
        _active = active;
        _completed = completed;
        _total = total;
        _progress = (completed / (float)MAX(total, 1u));
        _status = status;
        _error = error;

        NSLog(@"SYNCMGR: active=%d; status=%d; %u/%u; %@",
              active, status, completed, total, error.localizedDescription);
        // FIXME: temporary logging
//        [[NSNotificationCenter defaultCenter]
//         postNotificationName: SyncManagerStateChangedNotification
//         object: self];
    }
}


- (void)restartSync {
    NSLog(@"restartSync");
    [pull stop];
    [pull start];
    [push stop];
    [push start];
}

#pragma mark - User ID related

- (void)setupNewUser:(void (^)())complete {
    NSAssert(!_userID, @"already has userID");
    [_authenticator getCredentials: ^(NSString *userID, NSDictionary *userData){
        NSLog(@"got userID %@", userID);
        if (_userID) return;
        _userID = userID;
        // Give the app a chance to tag documents with userID before sync starts
        NSError *error = [self runBeforeSyncStartWithUserID:userID andUserData:userData];
        if (error) {
            NSLog(@"error preparing for sync %@", error);
        } else {
            complete();
        }
    }];
}

@end

@implementation CBLFacebookAuthenticator

@synthesize syncManager=_syncManager;

- (instancetype)initWithAppID:(NSString *)appID {
    self = [super init];
    if (self) {
        _facebookAppID = appID;
    }
    return self;
}

-(void)getCredentials:(void (^)(NSString *userID, NSDictionary *userData))block {
    [self getFaceBookAccessToken:^(NSString *accessToken, ACAccount *fbAccount) {
        [self getFacebookUserInfoWithAccessToken:accessToken facebookAccount:fbAccount onCompletion:^(NSDictionary *userData) {
            NSString *userID = userData[@"email"];
            
            // Store the access_token for later.
            [[NSUserDefaults standardUserDefaults] setObject:accessToken forKey:[self accessTokenKeyForUserID:userID]];
            
            block(userID, userData);
        }];
    }];
}

-(void)registerCredentialsWithReplications:(NSArray *)repls {
    NSString *userID = _syncManager.userID;
    NSString *accessToken = [[NSUserDefaults standardUserDefaults] objectForKey:[self accessTokenKeyForUserID:userID]];
    if (!userID) return;
    for (CBLReplication *repl in repls) {
        [repl setFacebookEmailAddress:userID];
        [repl registerFacebookToken:accessToken forEmailAddress:userID];
    }
}

#pragma mark - Facebook API related

- (void)getFacebookUserInfoWithAccessToken:(NSString *)accessToken
                           facebookAccount:(ACAccount *)fbAccount
                              onCompletion:(void (^)(NSDictionary *userData))complete {
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

- (NSString *)accessTokenKeyForUserID:(NSString *)userID {
    return [@"CBLFBAT-" stringByAppendingString: userID];
}

- (void)getFaceBookAccessToken:(void (^)(NSString *accessToken, ACAccount *fbAccount))complete {
    ACAccountStore *accountStore = [[ACAccountStore alloc]init];
    
    ACAccountType *FBaccountType= [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
    
    NSDictionary *dictFB = [NSDictionary dictionaryWithObjectsAndKeys:_facebookAppID, ACFacebookAppIdKey,
                            @[@"email"], ACFacebookPermissionsKey, nil];
    
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
             dispatch_async(dispatch_get_main_queue(), ^{
                 UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Account Error"
                                                                 message:@"There is no Facebook Accounts configured. You can configure a Facebook acount in Settings."
                                                                delegate:nil
                                                       cancelButtonTitle:@"Ok"
                                                       otherButtonTitles: nil];
                 [alert show];

             });
         }
     }];
}

@end
