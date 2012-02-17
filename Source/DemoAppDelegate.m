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
#define kSessionSyncDbURL @"http://single.couchbase.net/sessions"
#define kSessionControlHost @"http://single.couchbase.net/"

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
-(void)getUpToDateWithSubscriptions;
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
    gRESTLogLevel = kRESTLogRequestURLs;

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
            sessionSynced = YES;
            [self connectToControlDb];
            [[NSNotificationCenter defaultCenter] addObserver: self 
                                                     selector: @selector(sessionDatabaseChanged)
                                                         name: kCouchDatabaseChangeNotification 
                                                       object: self.sessionDatabase];
        } else {
            NSLog(@"session not active");
            [self syncSessionDocument];
        }
    } else {
        NSLog(@"no session");

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
    return [uuidStr lowercaseString];
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

-(CouchDocument*) makeInstallationForSubscription: (CouchDocument*)subscription withDatabaseNamed:(NSString*) name {
    CouchDocument *installation = [sessionDatabase untitledDocument];
    if (name == nil) {
        name = [@"channel-" stringByAppendingString:[self randomString]];
    }
    CouchDatabase *channelDb = [server databaseNamed: name];
    NSLog(@"create channel db %@",name);

    // Create the session database on the first run of the app.
    NSError* error;
    if (![channelDb ensureCreated: &error]) {
        NSLog(@"could not create channel db %@",name);
        exit(-1);
    }
    [[[installation putProperties:[NSDictionary dictionaryWithObjectsAndKeys:
                                   name, @"local_db_name", 
                                   [subscription.properties objectForKey:@"owner_id"], @"owner_id", 
                                   [subscription.properties objectForKey:@"channel_id"], @"channel_id", 
                                   sessionDoc.documentID, @"session_id", 
                                   subscription.documentID, @"subscription_id", 
                                   @"installation",@"type",
                                   @"created",@"state",
                                   nil]] start] wait];
    return installation;
}

-(CouchDocument*) makeSubscriptionForChannel: (CouchDocument*)channel andOwnerId:(NSString*) ownerId {
    CouchDocument *subscription = [sessionDatabase untitledDocument];
    [[[subscription putProperties:[NSDictionary dictionaryWithObjectsAndKeys:
                                   ownerId, @"owner_id", 
                                   channel.documentID, @"channel_id", 
                                   @"subscription",@"type",
                                   @"active",@"state",
                                   nil]] start] wait];
    return subscription;
}

//-(CouchDocument*) findChannelFor

-(void) maybeInitilizeDefaultChannel {
    CouchQueryEnumerator *rows = [[sessionDatabase getAllDocuments] rows];
    CouchQueryRow *row;
    
    CouchDocument *channel = nil; // global, owned by user and private by default
    CouchDocument *subscription = nil; // user
    CouchDocument *installation = nil; // per session
//    if we have a channel owned by the user, and it is flagged default == true,
//    then we don't need to make a channel doc or a subscription,
//    but we do need to make an installation doc that references the subscription.

//    if we don't have a default channel owned by the user, 
//    then we need to create it, and a subcription to it (by the owner).
//    also we create an installation doc linking the kDatabaseName (pre-pairing) database
//    with the channel & subscription.
        
//    note: need a channel doc and a subscription doc only makes sense when you need to 
//    allow for channels that are shared by multiple users.
    NSString *myUserId= [[sessionDoc.properties objectForKey:@"session"] objectForKey:@"user_id"];
    while ((row = [rows nextRow])) { 
        if ([[row.documentProperties objectForKey:@"type"] isEqualToString:@"channel"] && [[row.documentProperties objectForKey:@"owner_id"] isEqualToString:myUserId] && ([row.documentProperties objectForKey:@"default"] == [NSNumber numberWithBool:YES])) {
            channel = row.document;
        }
    }
    if (channel) {
        //    TODO use a query
        CouchQueryEnumerator *rows2 = [[sessionDatabase getAllDocuments] rows];
        while ((row = [rows2 nextRow])) {
            if ([[row.documentProperties objectForKey:@"local_db_name"] isEqualToString:kDatabaseName] && [[row.documentProperties objectForKey:@"session_id"] isEqualToString:sessionDoc.documentID] && [[row.documentProperties objectForKey:@"channel_id"] isEqualToString:channel.documentID]) {
                installation =  row.document;
            } else if ([[row.documentProperties objectForKey:@"type"] isEqualToString:@"subscription"] && [[row.documentProperties objectForKey:@"owner_id"] isEqualToString:myUserId] && [[row.documentProperties objectForKey:@"channel_id"] isEqualToString:channel.documentID]) {
                subscription = row.document;
            }
        }
        NSLog(@"channel %@", channel.description);
        NSLog(@"subscription %@", subscription.description);
        NSLog(@"installation %@", installation.description);
        if (subscription) {
            if (installation) {
//                we are set, sync will trigger based on the installation
            } else {
//                we have a subscription and a channel (created on another device)
//                but we do not have a local installation, so let's make one
                installation = [self makeInstallationForSubscription: subscription withDatabaseNamed:kDatabaseName];
            }
        } else {
//            channel but no subscription, maybe we crashed earlier or had a partial sync
            subscription = [self makeSubscriptionForChannel: channel andOwnerId:myUserId];
            if (installation) {
//                we already have an install doc for the local device, this should never happen
            } else {
                installation = [self makeInstallationForSubscription: subscription withDatabaseNamed:kDatabaseName];
            }
        }
    } else {
//     make a channel, subscription, and installation
        channel = [sessionDatabase untitledDocument];
        [[[channel putProperties:[NSDictionary dictionaryWithObjectsAndKeys:
                                     @"Default List", @"name",
                                        [NSNumber numberWithBool:YES], @"default",
                                     @"channel",@"type",
                                  myUserId, @"owner_id", 
                                     @"new",@"state",
                                     nil]] start] wait];
        subscription = [self makeSubscriptionForChannel: channel andOwnerId:myUserId];
        installation = [self makeInstallationForSubscription: subscription withDatabaseNamed:kDatabaseName];
    }
}


-(void)connectToControlDb {
    NSAssert([self sessionIsActive], @"session must be active");
    NSString *controlDB = [kSessionControlHost stringByAppendingString:[[sessionDoc.properties objectForKey:@"session"] objectForKey:@"control_database"]];
    NSLog(@"connecting to control database %@",controlDB);
    sessionPull = [self.sessionDatabase pullFromDatabaseAtURL:[NSURL URLWithString:controlDB]];
    [sessionPull start];
    [sessionPull retain];
    NSLog(@" sessionPull running %d",sessionPull.running);
    [sessionPull addObserver: self forKeyPath: @"running" options: 0 context: NULL];
    sessionPush = [self.sessionDatabase pushToDatabaseAtURL:[NSURL URLWithString:controlDB]];
    sessionPush.continuous = YES;
    [sessionPush start];
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object 
                         change:(NSDictionary *)change context:(void *)context
{
    NSLog(@" observeValueForKeyPath sessionPull running %d",sessionPull.running);
    if (object == sessionPull && (sessionPull.running == 0)) {
        NSString *controlDB = [kSessionControlHost stringByAppendingString:[[sessionDoc.properties objectForKey:@"session"] objectForKey:@"control_database"]];
        [sessionPull removeObserver: self forKeyPath: @"running"];
        [sessionPull stop];
        NSLog(@"finished first pull, checking channels status");
        [self maybeInitilizeDefaultChannel];
        [self getUpToDateWithSubscriptions];
        sessionPull = [self.sessionDatabase pullFromDatabaseAtURL:[NSURL URLWithString:controlDB]];
        sessionPull.continuous = YES;
        [sessionPull start];
    }
}

-(NSMutableArray*) activeSubscriptionsWithoutInstallations {
    NSMutableArray *subs = [NSMutableArray array];
    NSMutableArray *installed_sub_ids = [NSMutableArray array];
    NSMutableArray *results = [NSMutableArray array];
    NSString *myUserId= [[sessionDoc.properties objectForKey:@"session"] objectForKey:@"user_id"];
    CouchQueryEnumerator *rows = [[sessionDatabase getAllDocuments] rows];
    CouchQueryRow *row;
    while ((row = [rows nextRow])) {
        if ([[row.documentProperties objectForKey:@"type"] isEqualToString:@"subscription"] && [[row.documentProperties objectForKey:@"owner_id"] isEqualToString:myUserId] && [[row.documentProperties objectForKey:@"state"] isEqualToString:@"active"]) {
            [subs addObject:row.document];
        } else if ([[row.documentProperties objectForKey:@"type"] isEqualToString:@"installation"] && [[row.documentProperties objectForKey:@"session_id"] isEqualToString:sessionDoc.documentID]) {
            [installed_sub_ids addObject:[row.documentProperties objectForKey:@"subscription_id"]];
        }
    }
    [subs enumerateObjectsUsingBlock:^(CouchDocument *obj, NSUInteger idx, BOOL *stop) {
        if (NSNotFound == [installed_sub_ids indexOfObjectPassingTest:^(id sid, NSUInteger idx, BOOL *end){
            return [sid isEqualToString:obj.documentID];
        }]) {
            [results addObject:obj];
        }
    }];
    return results;
}

-(NSMutableArray*) createdInstallationsWithReadyChannels {
    NSString *myUserId= [[sessionDoc.properties objectForKey:@"session"] objectForKey:@"user_id"];
    CouchQueryEnumerator *rows = [[sessionDatabase getAllDocuments] rows];
    CouchQueryRow *row;
    NSMutableArray *installs = [NSMutableArray array];
    NSMutableArray *results = [NSMutableArray array];
    NSMutableArray *ready_channel_ids = [NSMutableArray array];
    while ((row = [rows nextRow])) {
        if ([[row.documentProperties objectForKey:@"type"] isEqualToString:@"installation"] && [[row.documentProperties objectForKey:@"state"] isEqualToString:@"created"] && [[row.documentProperties objectForKey:@"session_id"] isEqualToString:sessionDoc.documentID]) {
            [installs addObject:row.document];
        } else if ([[row.documentProperties objectForKey:@"type"] isEqualToString:@"channel"] && [[row.documentProperties objectForKey:@"state"] isEqualToString:@"ready"] && [[row.documentProperties objectForKey:@"owner_id"] isEqualToString:myUserId]) {
            [ready_channel_ids addObject:row.documentID];
        }
    }
    [installs enumerateObjectsUsingBlock:^(CouchDocument *obj, NSUInteger idx, BOOL *stop) {
        if (NSNotFound != [ready_channel_ids indexOfObjectPassingTest:^(id chid, NSUInteger idx, BOOL *end){
            return [chid isEqualToString:[obj.properties objectForKey:@"channel_id"]];
        }]) {
            [results addObject:obj];
        }
    }];
    return results;
}

-(void) getUpToDateWithSubscriptions {
    NSLog(@"getUpToDateWithSubscriptions");
    NSMutableArray *needInstalls = [self activeSubscriptionsWithoutInstallations]; // make installations for them
    [needInstalls enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSLog(@"make installation for sub %@", obj);
        [self makeInstallationForSubscription: obj withDatabaseNamed:nil];
    }];
    NSMutableArray *readyToSync = [self createdInstallationsWithReadyChannels]; // set up sync for these channels
    [readyToSync enumerateObjectsUsingBlock:^(CouchDocument *obj, NSUInteger idx, BOOL *stop) {
        NSLog(@"setup sync for installation %@", obj);
//        TODO setup sync with the database listed in "cloud_database" on the channel doc
//        this means we need the server side to actually make some channels "ready" first
        CouchDocument *channelDoc = [sessionDatabase documentWithID:[obj.properties objectForKey:@"channel_id"]];
        CouchDatabase *localChannelDb = [server databaseNamed: [obj.properties objectForKey:@"local_db_name"]];
        NSURL *cloudChannelURL = [NSURL URLWithString:[kSessionControlHost stringByAppendingString:[channelDoc.properties objectForKey:@"cloud_database"]]];
        CouchReplication *pull = [localChannelDb pullFromDatabaseAtURL:cloudChannelURL];
        pull.continuous = YES;
        CouchReplication *push = [localChannelDb pushToDatabaseAtURL:cloudChannelURL];
        push.continuous = YES;
    }];
}


-(void)sessionDatabaseChanged {
    NSLog(@"sessionDatabaseChanged sessionSynced: %d", sessionSynced);
    if ((sessionSynced != YES) && [self sessionIsActive]) {
        if (sessionPull && sessionPush) {
            NSLog(@"switch to user control db, pull %@ push %@", sessionPull, sessionPush);
            [sessionPull stop];
            NSLog(@"stopped pull, stopping push");
            [sessionPush stop];
        }
        sessionSynced = YES;

        [self connectToControlDb];
    } else {
        NSLog(@"change on local session db");
//        re run state manager for subscription docs
        [self getUpToDateWithSubscriptions];
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
