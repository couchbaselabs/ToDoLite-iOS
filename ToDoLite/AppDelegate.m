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

// Sync Gateway
#define kSyncGatewayUrl @"http://demo.mobile.couchbase.com/todolite"
#define kSyncGatewayWebSocketSupport NO

// Facebook APP ID
#define kFBAppId @"501518809925546"

// Guest DB Name
#define kGuestDBName @"guest"

// For Application Migration
#define kMigrationVersion @"MigrationVersion"

@interface AppDelegate () <UISplitViewControllerDelegate>

@property (nonatomic) CBLReplication *push;
@property (nonatomic) CBLReplication *pull;
@property (nonatomic) NSError *lastSyncError;
@property (copy, nonatomic) void (^facebookLoginResultBlock)(BOOL success, NSError *error);

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self migrateOldVersionApp];
    
    if ([self isFirstTimeUsed] || self.isGuestLoggedIn) {
        [self loginAsGuest];
    }
    
    if (FBSession.activeSession.state == FBSessionStateCreatedTokenLoaded) {
        // If there's one, just open the session silently, without showing the user the login UI
        [self openFacebookSessionWithUIDisplay:NO];
    }
    
    BOOL shouldSkipLogin = [self isUserLoggedIn] || [self isGuestLoggedIn];
    LoginViewController *loginViewController = (LoginViewController *)self.window.rootViewController;
    loginViewController.shouldSkipLogin = shouldSkipLogin;
    
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [FBAppCall handleDidBecomeActive];
}

// During the Facebook login flow, your app passes control to the Facebook iOS app or Facebook in a mobile browser.
// After authentication, your app will be called back with the session information.
// Override application:openURL:sourceApplication:annotation to call the FBsession object that handles the incoming URL
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    return [FBSession.activeSession handleOpenURL:url];
}

- (void)replaceRootViewController:(UIViewController *)controller {
    if ([controller isKindOfClass:[UISplitViewController class]]) {
        // Setup SplitViewController
        UISplitViewController *splitViewController = (UISplitViewController *)controller;
        if ([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] != NSOrderedAscending) {
            if ([[splitViewController.viewControllers lastObject] isKindOfClass:[UINavigationController class]]) {
                UINavigationController *navigationController = [splitViewController.viewControllers lastObject];
                navigationController.topViewController.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem;
            }
        }
        splitViewController.delegate = self;
    }
    self.window.rootViewController = controller;
}

#pragma mark - Properties

- (NSString *)currentUserId {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:@"user_id"];
}

- (void)setCurrentUserId:(NSString *)userId {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:userId forKey:@"user_id"];
    [defaults synchronize];
}

#pragma mark - Message

- (void)showMessage:(NSString *)text withTitle:(NSString *)title {
    [[[UIAlertView alloc] initWithTitle:title
                                message:text
                               delegate:self
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
}

#pragma mark - Database

- (void)setCurrentDatabase:(CBLDatabase *)database {
    [self willChangeValueForKey:@"database"];
    _database = database;
    [self didChangeValueForKey:@"database"];
}

- (NSString *)databaseNameForName:(NSString *)name {
    return [NSString stringWithFormat:@"db%@", [[name MD5] lowercaseString]];
}

- (CBLDatabase *)databaseForName:(NSString *)name {
    NSString *dbName = [self databaseNameForName:name];
    NSError *error;
    CBLDatabase *database = [[CBLManager sharedInstance] databaseNamed:dbName error:&error];
    if (error) {
        NSLog(@"Cannot create database with an error : %@", [error description]);
    }
    return database;
}

- (CBLDatabase *)databaseForUser:(NSString *)user {
    if (!user) return nil;
    return [self databaseForName:user];
}

- (CBLDatabase *)databaseForGuest {
    return [self databaseForName:kGuestDBName];
}

#pragma mark - Migration

- (void)migrateOldVersionApp {
    NSString *mVer = [[NSUserDefaults standardUserDefaults] objectForKey:kMigrationVersion];
    if (!mVer || [mVer compare:@"1.3" options:NSNumericSearch] == NSOrderedAscending) {
        CBLManager *manager = [CBLManager sharedInstance];
        CBLDatabase *todosDb = [manager existingDatabaseNamed:@"todos" error:nil];
        if (!todosDb) {
            return;
        }
        
        if (todosDb.lastSequenceNumber > 0) {
            NSString *userId = [[NSUserDefaults standardUserDefaults] objectForKey:@"CBLFBUserID"];
            NSString *dbName;
            if (userId) {
                dbName = [self databaseNameForName:userId];
            } else {
                dbName = [self databaseNameForName:kGuestDBName];
            }
            
            NSString *oldDbPath = [[manager directory] stringByAppendingPathComponent:@"todos.cblite"];
            NSString *oldDbAttachmentPath = [[oldDbPath stringByDeletingPathExtension]
                                             stringByAppendingString:@" attachments"];
            NSError *error;
            [manager replaceDatabaseNamed:dbName
                         withDatabaseFile:oldDbPath
                          withAttachments:oldDbAttachmentPath
                                    error:&error];
            if (error) {
                NSLog(@"Cannot replace database when migrating the app to v1.3 with an error: %@",
                      [error description]);
            }
        }
        
        NSError *error;
        [todosDb deleteDatabase:&error];
        if (error) {
            NSLog(@"Cannot delete 'todos' database when migrating the app to v1.3 with an error: %@",
                  [error description]);
        }
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"CBLFBUserID"];
        [[NSUserDefaults standardUserDefaults] setObject:@"1.3" forKey:kMigrationVersion];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

#pragma mark - Replication

- (void)startReplicationWithFacebookAccessToken:(NSString *)token {
    NSAssert(token, @"Facebook token is nil");
    
    if (!_pull) {
        NSURL *syncUrl = [NSURL URLWithString:kSyncGatewayUrl];
        _pull = [self.database createPullReplication:syncUrl];
        _pull.continuous  = YES;
        if (!kSyncGatewayWebSocketSupport) {
            _pull.customProperties = @{@"websocket": @NO};
        }
        
        _push = [self.database createPushReplication:syncUrl];
        _push.continuous = YES;
        
        // Observe replication progress changes, in both directions:
        NSNotificationCenter *nctr = [NSNotificationCenter defaultCenter];
        [nctr addObserver:self selector:@selector(replicationProgress:)
                     name:kCBLReplicationChangeNotification object:_pull];
        [nctr addObserver: self selector: @selector(replicationProgress:)
                     name:kCBLReplicationChangeNotification object:_push];
    }
    
    id <CBLAuthenticator> auth = [CBLAuthenticator facebookAuthenticatorWithToken:token];
    _pull.authenticator = auth;
    _push.authenticator = auth;
    
    [_push start];
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
        [nctr removeObserver:self name:kCBLReplicationChangeNotification object:_pull];
        _pull = nil;
    }
    if (_push) {
        [_push stop];
        [nctr removeObserver:self name:kCBLReplicationChangeNotification object:_push];
        _pull = nil;
    }
}

#pragma mark - Login & Logout

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

- (void)loginAsGuest {
    CBLDatabase *database = [self databaseForGuest];
    [self setCurrentDatabase:database];
    [self setGuestLoggedIn:YES];
    [self setCurrentUserId:nil];
    
    // Found that sometimes facebook session is still open even after remove and reintalling the app.
    // Ensure that the facebook session is clear.
    [FBSession.activeSession closeAndClearTokenInformation];
}

- (void)openFacebookSessionWithUIDisplay:(BOOL)display {
    [FBSession openActiveSessionWithReadPermissions:@[@"public_profile"]
                                       allowLoginUI:display
                                  completionHandler:
     ^(FBSession *session, FBSessionState state, NSError *error) {
         [self facebookSessionStateChanged:session state:state error:error];
     }];
}

- (void)loginWithFacebook:(void (^)(BOOL success, NSError *error))resultBlock {
    self.facebookLoginResultBlock = resultBlock;
    [self openFacebookSessionWithUIDisplay:YES];
}

- (void)loginWithFacebookUserInfo:(NSDictionary *)info accessTokenData:(FBAccessTokenData *)tokenData {
    NSAssert(tokenData, @"Facebook Access Token Data is nil");
    
    NSString *userId = [info objectForKey:@"email"];
    NSString *name = [info objectForKey:@"name"];
    
    [self setCurrentUserId:userId];
    
    CBLDatabase *database = [self databaseForUser:userId];
    [self setCurrentDatabase:database];
    [self setGuestLoggedIn:NO];
    
    Profile *profile = [Profile profileInDatabase:database forUserID:userId];
    if (!profile) {
        profile = [[Profile alloc] initProfileInDatabase:self.database withName:name andUserID:userId];
        NSError *error;
        if ([profile save:&error]) {
            [self migrateGuestDataToUser:profile];
        } else {
            NSLog(@"Cannot create a new user profile : %@", [error description]);
            [self showMessage:@"Cannot create a new user profile" withTitle:@"Error"];
        }
    }
    
    if (profile) {
        [self startReplicationWithFacebookAccessToken:tokenData.accessToken];
    }
}

- (void)logout {
    [FBSession.activeSession closeAndClearTokenInformation];
    [self setCurrentUserId:nil];
    [self stopReplication];
    [self setCurrentDatabase:nil];
    
    [self performSelector:@selector(replaceRootViewController:)
               withObject:[self.window.rootViewController.storyboard instantiateInitialViewController]
               afterDelay:0.0];
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
                    [rev setAttachmentNamed:att.name withContentType:att.contentType content:att.content];
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

- (void)migrateGuestDataIfAvailableToUserDatabase:(CBLDatabase *)userDB {
    CBLManager *manager = [CBLManager sharedInstance];
    CBLDatabase *guestDB = [self databaseForGuest];
    if (guestDB.lastSequenceNumber > 0) {
        NSString *guestDBPath = [[manager directory] stringByAppendingPathComponent:
                                 [NSString stringWithFormat:@"%@.cblite",
                                  [self databaseNameForName:kGuestDBName]]];
        NSString *guestAttPath = [[guestDBPath stringByDeletingPathExtension]
                                  stringByAppendingString:@" attachments"];
        NSError *error;
        [manager replaceDatabaseNamed:userDB.name
                     withDatabaseFile:guestDBPath
                      withAttachments:guestAttPath
                                error:&error];
        if (error) {
            NSLog(@"Migrating guest data has an error : %@", [error description]);
        }
    }
    
    NSError *error;
    [guestDB deleteDatabase:&error];
    if (error) {
        NSLog(@"Migrating guest data, deleting the guest database has an error : %@", [error description]);
    }
}

#pragma mark - Facebook

- (void)notifyFacebookLoginResult:(BOOL)success error:(NSError *)error {
    if (self.facebookLoginResultBlock) {
        self.facebookLoginResultBlock(success, error);
        self.facebookLoginResultBlock = nil;
    }
}

- (void)facebookSessionStateChanged:(FBSession *)session state:(FBSessionState) state error:(NSError *)error {
    if (!error && state == FBSessionStateOpen){
        [FBRequestConnection startForMeWithCompletionHandler:
         ^(FBRequestConnection *connection, id result, NSError *error) {
             if (!error) {
                 [self loginWithFacebookUserInfo:(NSDictionary *)result accessTokenData:session.accessTokenData];
             } else {
                 [FBSession.activeSession closeAndClearTokenInformation];
             }
            [self notifyFacebookLoginResult:(!error) error:error];
         }];
        return;
    }
    
    if (state == FBSessionStateClosedLoginFailed) {
        [self notifyFacebookLoginResult:NO error:error];
        [FBSession.activeSession closeAndClearTokenInformation];
        return;
    }
    
    if (error) {
        // If the error requires people using an app to make an action outside of the app in order to recover
        if ([FBErrorUtility shouldNotifyUserForError:error] == YES){
            [self showMessage:[FBErrorUtility userMessageForError:error] withTitle:@"Facebook Error"];
        } else {
            if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryUserCancelled) {
                // The user cancelled login. Do nothing
            } else if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryAuthenticationReopenSession){
                [self showMessage:@"Your current facebook session is no longer valid. Please logout and relogin again"
                        withTitle:@"Session Error"];
            } else {
                NSDictionary *info = [[[error.userInfo objectForKey:@"com.facebook.sdk:ParsedJSONResponseKey"]
                                                   objectForKey:@"body"] objectForKey:@"error"];
                NSString *mesg = [NSString stringWithFormat:@"Facebook error with code: %@", [info objectForKey:@"message"]];
                [self showMessage:mesg withTitle:@"Facebook Error"];
            }
        }
        
        [self notifyFacebookLoginResult:NO error:error];
        [FBSession.activeSession closeAndClearTokenInformation];
    }
}

#pragma mark - Split view

- (BOOL)splitViewController:(UISplitViewController *)splitViewController collapseSecondaryViewController:(UIViewController *)secondaryViewController ontoPrimaryViewController:(UIViewController *)primaryViewController {
    if ([secondaryViewController isKindOfClass:[UINavigationController class]] &&
        [[(UINavigationController *)secondaryViewController topViewController] isKindOfClass:[DetailViewController class]] &&
        ([(DetailViewController *)[(UINavigationController *)secondaryViewController topViewController] list] == nil)) {
        return YES;
    } else {
        return NO;
    }
}

- (void)splitViewController:(UISplitViewController *)splitViewController
     willHideViewController:(UIViewController *)viewController
          withBarButtonItem:(UIBarButtonItem *)barButtonItem
       forPopoverController:(UIPopoverController *)popoverController {
    
    if ([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] == NSOrderedAscending) {
        // For iOS7
        UINavigationController *navigationController = [splitViewController.viewControllers lastObject];
        navigationController.topViewController.navigationItem.leftBarButtonItem = barButtonItem;
    }
    
    _popoverController = popoverController;
    _displayModeButtonItem = barButtonItem;
}

@end
