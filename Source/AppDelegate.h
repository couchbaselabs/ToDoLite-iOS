//
//  AppDelegate.h
//  ToDoLite
//
//  Created by Jan Lehnardt on 27/11/2010.
//  Copyright 2011-2013 Couchbase, Inc.
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

#import <UIKit/UIKit.h>
@class CBLDatabase, ListController;


@interface AppDelegate : NSObject <UIApplicationDelegate, UIAlertViewDelegate>

@property (nonatomic) CBLDatabase *database;

/** The URL of the remote server database to replicate with.
    Setting this property updates the database's replications for the new URL. */
@property NSURL* syncURL;

/** Utility method to display an error alert. */
- (void)showAlert: (NSString*)message error: (NSError*)error fatal: (BOOL)fatal;

@end


/** The singleton AppDelegate instance. */
extern AppDelegate* gAppDelegate;

/** YES if on an iPad, NO if an iPhone. */
extern BOOL gRunningOnIPad;
