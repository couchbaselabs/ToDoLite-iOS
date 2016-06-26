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
#import "NSString+Additions.h"

// Sync Gateway:
#define kSyncGatewayUrl @"http://demo-mobile.couchbase.com/todolite"
//#define kSyncGatewayUrl @"http://<IP>:4984/todos"

// Enable/disable WebSocket in pull replication:
#define kSyncGatewayWebSocketSupport YES

// Guest DB Name:
#define kGuestDBName @"guest"

// Storage Type: kCBLSQLiteStorage or kCBLForestDBStorage
#define kStorageType kCBLSQLiteStorage

// Encryption:
// Note: This is just a sample showing how to set an encryption key.
// In the any production apps, generate an encryption key and keep it
// in the secure storage (e.g. keychain), not in source code.
#define kEncryptionEnabled NO
#define kEncryptionKey @"Seekrit"

// Enable or disable logging:
#define kLoggingEnabled NO

@interface AppDelegate () <UIAlertViewDelegate, LoginViewControllerDelegate>

@property (nonatomic) CBLReplication *push;
@property (nonatomic) CBLReplication *pull;
@property (nonatomic) NSError *lastSyncError;
@property (nonatomic) LoginViewController *loginViewController;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self enableLogging];

    [LoginViewController application:application
       didFinishLaunchingWithOptions:launchOptions];

    self.loginViewController = (LoginViewController *)self.window.rootViewController;
    self.loginViewController.delegate = self;

    if ([self isFirstTimeUsed] || [self isGuestLoggedIn])
        [self.loginViewController loginAsGuest];
    else
        [self.loginViewController tryLogin];

    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    return [LoginViewController application:application
                                    openURL:url
                          sourceApplication:sourceApplication
                                 annotation:annotation];
}

#pragma mark - Logging

- (void)enableLogging {
    if (kLoggingEnabled) {
        [CBLManager enableLogging:@"Database"];
        [CBLManager enableLogging:@"View"];
        [CBLManager enableLogging:@"ViewVerbose"];
        [CBLManager enableLogging:@"Query"];
        [CBLManager enableLogging:@"Sync"];
        [CBLManager enableLogging:@"SyncVerbose"];
        [CBLManager enableLogging:@"ChangeTracker"];
    }
}

#pragma mark - Database

- (void)setCurrentDatabase:(CBLDatabase *)database {
    [self willChangeValueForKey:@"database"];
    _database = database;
    [self didChangeValueForKey:@"database"];
}

- (CBLDatabase *)databaseForName:(NSString *)name {
    NSString *dbName = [NSString stringWithFormat:@"db%@", [[name MD5] lowercaseString]];

    CBLDatabaseOptions *option = [[CBLDatabaseOptions alloc] init];
    option.create = YES;
    option.storageType = kStorageType;
    
    if (kEncryptionEnabled)
        option.encryptionKey = kEncryptionKey;

    NSError *error;
    CBLDatabase *database = [[CBLManager sharedInstance] openDatabaseNamed:dbName
                                                               withOptions:option
                                                                     error:&error];
    if (error)
        NSLog(@"Cannot create database with an error : %@", [error description]);

    return database;
}

- (CBLDatabase *)databaseForUser:(NSString *)user {
    if (!user) return nil;
    return [self databaseForName:user];
}

- (CBLDatabase *)databaseForGuest {
    return [self databaseForName:kGuestDBName];
}

#pragma mark - Replication

- (void)startReplicationWithAuthenticator:(id <CBLAuthenticator>)authenticator {
    if (!_pull) {
        NSURL *syncUrl = [NSURL URLWithString:kSyncGatewayUrl];
        _pull = [self.database createPullReplication:syncUrl];
        _pull.continuous  = YES;
        if (!kSyncGatewayWebSocketSupport)
            _pull.customProperties = @{@"websocket": @NO};
        
        _push = [self.database createPushReplication:syncUrl];
        _push.continuous = YES;
        
        // Observe replication progress changes, in both directions:
        NSNotificationCenter *nctr = [NSNotificationCenter defaultCenter];
        [nctr addObserver:self selector:@selector(replicationProgress:)
                     name:kCBLReplicationChangeNotification object:_pull];
        [nctr addObserver: self selector: @selector(replicationProgress:)
                     name:kCBLReplicationChangeNotification object:_push];
    }

    _pull.authenticator = authenticator;
    _push.authenticator = authenticator;

    if (_push.running)
        [_push stop];
    [_push start];

    if (_pull.running)
        [_pull stop];
    [_pull start];
}

- (void)replicationProgress:(NSNotification *)notification {
    if (_pull.status == kCBLReplicationActive || _push.status == kCBLReplicationActive) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    } else {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    }
    
    // Check for any change in error status and display new errors:
    NSError* error = _pull.lastError ? _pull.lastError : _push.lastError;
    if (error != _lastSyncError) {
        _lastSyncError = error;
        if (error) {
            // TODO: Handle sync error properly
        }
    }
}

- (void)stopReplication {
    NSNotificationCenter *nctr = [NSNotificationCenter defaultCenter];
    if (_pull) {
        [_pull stop];
        [_pull deleteCookieNamed:@"SyncGatewaySession"];
        [nctr removeObserver:self name:kCBLReplicationChangeNotification object:_pull];
        _pull = nil;
    }
    if (_push) {
        [_push stop];
        [_push deleteCookieNamed:@"SyncGatewaySession"];
        [nctr removeObserver:self name:kCBLReplicationChangeNotification object:_push];
        _pull = nil;
    }
}

#pragma mark - LoginViewControllerDelegate

- (void)didLogInAsGuest {
    CBLDatabase *database = [self databaseForGuest];
    [self setCurrentDatabase:database];
    [self setGuestLoggedIn:YES];
    [self setCurrentUserId:nil];
}

- (void)didLogInAsFacebookUserId:(NSString *)userId name:(NSString *)name token:(NSString *)token {
    [self setCurrentUserId:userId];

    CBLDatabase *database = [self databaseForUser:userId];
    [self setCurrentDatabase:database];
    [self setGuestLoggedIn:NO];

    Profile *profile = [Profile profileInDatabase:database forExistingUserId:userId];
    if (!profile) {
        if (name) {
            NSError *error;
            profile = [Profile profileInDatabase:database forNewUserId:userId name:name];
            if ([profile save:&error])
                [self migrateGuestDataToUser:profile];
            else
                NSLog(@"Cannot create a new user profile with error : %@", error);
        } else
            NSLog(@"Cannot create a new user profile as there is no name information.");
    }

    if (profile)
        [self startReplicationWithAuthenticator:
         [CBLAuthenticator facebookAuthenticatorWithToken:token]];
    else
        [self showMessage:@"Cannot create a new user profile" withTitle:@"Error"];
}

- (void)didLogout {
    [self setCurrentUserId:nil];
    [self stopReplication];
    [self setCurrentDatabase:nil];

    self.loginViewController = [self.window.rootViewController.storyboard
                                instantiateInitialViewController];
    self.loginViewController.delegate = self;
    self.window.rootViewController = self.loginViewController;
}

#pragma mark - Login & Logout

- (NSString *)currentUserId {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:@"user_id"];
}

- (void)setCurrentUserId:(NSString *)userId {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:userId forKey:@"user_id"];
    [defaults synchronize];
}

- (BOOL)isFirstTimeUsed {
    return [[[CBLManager sharedInstance] allDatabaseNames] count] == 0;
}

- (BOOL)isUserLoggedIn {
    return self.currentUserId != nil;
}

- (BOOL)isGuestLoggedIn {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [[defaults objectForKey:@"guest"] boolValue];
}

- (void)setGuestLoggedIn:(BOOL)status {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithBool:status] forKey:@"guest"];
    [defaults synchronize];
}

- (void)logout {
    [self.loginViewController logout];
}

- (void)migrateGuestDataToUser:(Profile *)profile {
    CBLDatabase *guestDB = [self databaseForGuest];
    if (guestDB.lastSequenceNumber > 0) {
        CBLQueryEnumerator *rows = [[guestDB createAllDocumentsQuery] run:nil];
        if (!rows) {
            return;
        }
        
        NSError *error;
        CBLDatabase *userDB = profile.database;
        for (CBLQueryRow *row in rows) {
            CBLDocument *doc = row.document;
            
            CBLDocument *newDoc = [userDB documentWithID:doc.documentID];
            [newDoc putProperties:doc.userProperties error:&error];
            if (error) {
                NSLog(@"Error when saving a new document during migrating guest data : %@",
                      [error description]);
                continue;
            }
            
            NSArray *attachments = doc.currentRevision.attachments;
            if ([attachments count] > 0) {
                CBLUnsavedRevision *rev = [newDoc.currentRevision createRevision];
                for (CBLAttachment *att in attachments) {
                    [rev setAttachmentNamed:att.name
                            withContentType:att.contentType
                                    content:att.content];
                }
                
                CBLSavedRevision *saved = [rev save:&error];
                if (!saved) {
                    NSLog(@"Error when saving an attachment during migrating guest data : %@",
                          [error description]);
                }
            }
        }
        
        error = nil;
        [List updateAllListsInDatabase:profile.database withOwner:profile error:&error];
        if (error) {
            NSLog(@"Error when transfering the ownership of the list documents : %@",
                  [error description]);
        }
        
        error = nil;
        if (![guestDB deleteDatabase:&error]) {
            NSLog(@"Error when deleting the guest database during migrating guest data : %@",
                  [error description]);
        }
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
