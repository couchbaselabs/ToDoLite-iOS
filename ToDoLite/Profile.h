//
//  Profile.h
//  TodoLite7
//
//  Created by Chris Anderson on 11/15/13.
//  Copyright (c) 2013 Chris Anderson. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>

@interface Profile : CBLModel

/** Returns a query for all the profiles in a database. */
+ (CBLQuery*) queryProfilesInDatabase: (CBLDatabase*)db;

+ (instancetype) profileInDatabase: (CBLDatabase*)db forExistingUserId: (NSString*)userId;

+ (instancetype) profileInDatabase: (CBLDatabase*)database forNewUserId: (NSString*)userId name: (NSString*)name;

/** The readwrite full name. */
@property (readwrite) NSString* name;

/** The user id. */
@property (readwrite) NSString* user_id;

/** The type is "profile". */
@property (copy, nonatomic) NSString* type;

@end
