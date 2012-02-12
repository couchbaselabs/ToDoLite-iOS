//
//  DemoAppDelegate.m
//  Couchbase Mobile
//
//  Created by Jan Lehnardt on 27/11/2010.
//  Copyright 2011 Couchbase, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not
// use this file except in compliance with the License. You may obtain a copy of
// the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations under
// the License.
//

#import "DemoAppDelegate.h"
#import "RootViewController.h"
#import <CouchCocoa/CouchCocoa.h>
#import <CouchCocoa/CouchTouchDBServer.h>

// The name of the database the app will use.
#define kDatabaseName @"grocery-sync"
#define kSessionDatabaseName @"sessions"
#define kSessionSyncDbURL @"http://127.0.0.1:5984/sessions"
#define kSessionControlHost @"http://127.0.0.1:5984/"

// The default remote database URL to sync with, if the user hasn't set a different one as a pref.
//#define kDefaultSyncDbURL @"http://couchbase.iriscouch.com/grocery-sync"

// Define this to use a server at a specific URL, instead of the embedded Couchbase Mobile.
// This can be useful for debugging, since you can use the admin console (futon) to inspect
// or modify the database contents.
//#define USE_REMOTE_SERVER @"http://localhost:5984/"


@interface DemoAppDelegate ()
- (void) connectToControlDb;
- (void) loadSessionDocument;
- (void) syncSessionDocument;
-(BOOL)sessionIsActive;
-(void)sessionDatabaseChanged;
@end

@implementation DemoAppDelegate

@synthesize facebook;
@synthesize window;
@synthesize navigationController;
@synthesize database, sessionDatabase;


// Override point for customization after application launch.
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"------ application:didFinishLaunchingWithOptions:");
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

#ifdef kDefaultSyncDbURL
    // Register the default value of the pref for the remote database URL to sync with:
    NSDictionary *appdefaults = [NSDictionary dictionaryWithObject:kDefaultSyncDbURL
                                                            forKey:@"syncpoint"];
    [defaults registerDefaults:appdefaults];
    [defaults synchronize];
#endif
    
    // Add the navigation controller's view to the window and display.
	[window addSubview:navigationController.view];
	[window makeKeyAndVisible];

    // Start the Couchbase Mobile server:
    gCouchLogLevel = 3;
    CouchTouchDBServer* server;
#ifdef USE_REMOTE_SERVER
    server = [[CouchTouchDBServer alloc] initWithURL: [NSURL URLWithString: USE_REMOTE_SERVER]];
#else
    server = [[CouchTouchDBServer alloc] init];
#endif
    
    if (server.error) {
        [self showAlert: @"Couldn't start Couchbase." error: server.error fatal: YES];
        return YES;
    }
    
    self.database = [server databaseNamed: kDatabaseName];
// todo   should be moved to SyncpointClient
    self.sessionDatabase = [server databaseNamed: kSessionDatabaseName];

    // Create the session database on the first run of the app.
    NSError* error;
    if (![self.sessionDatabase ensureCreated: &error]) {
        [self showAlert: @"Couldn't create session database." error: error fatal: YES];
        return YES;
    }
    
#if !INSTALL_CANNED_DATABASE && !defined(USE_REMOTE_SERVER)
    // Create the database on the first run of the app.

    if (![self.database ensureCreated: &error]) {
        [self showAlert: @"Couldn't create local database." error: error fatal: YES];
        return YES;
    }
#endif
    
    database.tracksChanges = YES;
    sessionDatabase.tracksChanges = YES;
    
    // Tell the RootViewController:
    RootViewController* root = (RootViewController*)navigationController.topViewController;
    [root useDatabase: database];

    if ([self syncpointSessionId]) {
        NSLog(@"has session");
        [self loadSessionDocument];
        if ([self sessionIsActive]) {
            //        setup sync with the user control database
            NSLog(@"go directly to user control");
            [self connectToControlDb];
        } else {
            NSLog(@"session not active");
            [self syncSessionDocument];
        }
    } else {
        NSLog(@"no session");

//        [self syncSessionDocument];
        //    setup facebook
        facebook = [[Facebook alloc] initWithAppId:@"251541441584833" andDelegate:self];
        if ([defaults objectForKey:@"FBAccessTokenKey"] && [defaults objectForKey:@"FBExpirationDateKey"]) {
            facebook.accessToken = [defaults objectForKey:@"FBAccessTokenKey"];
            facebook.expirationDate = [defaults objectForKey:@"FBExpirationDateKey"];
        }
    }
    return YES;
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    return [self.facebook handleOpenURL:url];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    return [self.facebook handleOpenURL:url];
}

- (NSString*) randomString {
    CFUUIDRef uuidObject = CFUUIDCreate(kCFAllocatorDefault);
    NSString *uuidStr = (__bridge NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuidObject);
    CFRelease(uuidObject);
    return uuidStr;
}

- (NSMutableDictionary*) randomOAuthCreds {
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [self randomString], @"consumer_key",
            [self randomString], @"consumer_secret",
            [self randomString], @"token_secret",
            [self randomString], @"token",
            nil];
}

- (id)syncpointSessionId {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:@"sessionDocId"];
}

-(BOOL)sessionIsActive {
    NSLog(@"sessionIsActive? %@",[sessionDoc.properties objectForKey:@"state"]);
    return [[sessionDoc.properties objectForKey:@"state"] isEqualToString:@"active"];
}

-(void) loadSessionDocument{
    sessionDoc = [sessionDatabase documentWithID:[self syncpointSessionId]];
}
-(void) syncSessionDocument {
    [[self.sessionDatabase pushToDatabaseAtURL:[NSURL URLWithString:kSessionSyncDbURL]] start];
    NSLog(@"syncSessionDocument pull");

    sessionPull = [self.sessionDatabase pullFromDatabaseAtURL:[NSURL URLWithString:kSessionSyncDbURL]];
//    todo add a by docid read rule so I only see my document
    sessionPull.filter = @"_doc_ids";
    
    NSString *docIdsString = [NSString stringWithFormat:@"[\"%@\"]",
                         sessionDoc.documentID];
    
    sessionPull.filterParams = [NSDictionary dictionaryWithObjectsAndKeys: 
                                docIdsString
                                , @"doc_ids", 
                                nil];
    sessionPull.continuous = YES;
    [sessionPull start];
    NSLog(@"syncSessionDocument pulled");

//    ok now we should listen to changes on the session db and stop replication 
//    when we get our doc back in a finalized state
    sessionSynced = NO;
    NSLog(@"observing session db");
    [[NSNotificationCenter defaultCenter] addObserver: self 
                                             selector: @selector(sessionDatabaseChanged)
                                                 name: kCouchDatabaseChangeNotification 
                                               object: self.sessionDatabase];
}

-(void)connectToControlDb {
    NSAssert([self sessionIsActive], @"session must be active");
    NSString *controlDB = [kSessionControlHost stringByAppendingString:[[sessionDoc.properties objectForKey:@"session"] objectForKey:@"control_database"]];
    NSLog(@"connecting to control database %@",controlDB);
    sessionPull = [self.sessionDatabase pullFromDatabaseAtURL:[NSURL URLWithString:controlDB]];
    sessionPull.continuous = YES;
    [sessionPull start];
    sessionPush = [self.sessionDatabase pushToDatabaseAtURL:[NSURL URLWithString:controlDB]];
    sessionPush.continuous = YES;
    [sessionPush start];
}

// we should only be here if our session is inactive
// the change may have made our session active,
// if so, we can switch to "logged-in" mode.

-(void)sessionDatabaseChanged {
    NSLog(@"sessionDatabaseChanged, sessionSynced %@", sessionSynced);
    if (!sessionSynced && [self sessionIsActive]) {
        NSLog(@"switch to user control db");
        sessionSynced = YES;
        [sessionPull stop];
        [sessionPush stop];
        [self connectToControlDb];
    }
}

//


- (void)getSyncpointSessionFromFBAccessToken:(id) accessToken {
    //  it's possible we could log into facebook even though we already have
    //  a Syncpoint session. This guard is to prevent extra requests.
    if (![self syncpointSessionId]) {
//        save a document that has the facebook access code, to the handshake database.
//        the document also needs to have the oath credentials we'll use when replicating.
//        the server will use the access code to find the facebook uid, which we can use to 
//        look up the syncpoint user, and link these credentials to that user (establishing our session)
        NSMutableDictionary *sessionData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             accessToken, @"fb_access_token",
                                             [self randomOAuthCreds], @"oauth_creds",
                                            @"new", @"state",
                                            @"session-fb",@"type",
//      todo this document needs to have our devices SSL cert signature in it
//      so we can enforce that only this device can read this document
                                             nil];
        NSLog(@"session data %@",[sessionData description]);
        sessionDoc = [self.sessionDatabase untitledDocument];
        RESTOperation *op = [[sessionDoc putProperties:sessionData] start];
        [op onCompletion:^{
            if (op.error) {
                NSLog(@"op error %@",op.error);                
            } else {
                NSLog(@"session doc %@",[sessionDoc description]);
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setObject:sessionDoc.documentID forKey:@"sessionDocId"];
                [defaults synchronize];
                [self syncSessionDocument];
            }
        }];
    }
}


- (void)fbDidLogin {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[facebook accessToken] forKey:@"FBAccessTokenKey"];
    [defaults setObject:[facebook expirationDate] forKey:@"FBExpirationDateKey"];
    [defaults synchronize];
    [self getSyncpointSessionFromFBAccessToken: [facebook accessToken]];
}

/**
 * Called when the user canceled the authorization dialog.
 */
-(void)fbDidNotLogin:(BOOL)cancelled {
    // we don't have anything really to do here
}


// Display an error alert, without blocking.
// If 'fatal' is true, the app will quit when it's pressed.
- (void)showAlert: (NSString*)message error: (NSError*)error fatal: (BOOL)fatal {
    if (error) {
        message = [NSString stringWithFormat: @"%@\n\n%@", message, error.localizedDescription];
    }
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle: (fatal ? @"Fatal Error" : @"Error")
                                                    message: message
                                                   delegate: (fatal ? self : nil)
                                          cancelButtonTitle: (fatal ? @"Quit" : @"Sorry")
                                          otherButtonTitles: nil];
    [alert show];
    [alert release];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    exit(0);
}


- (void)dealloc {
	[navigationController release];
	[window release];
    [database release];
	[super dealloc];
}


@end
