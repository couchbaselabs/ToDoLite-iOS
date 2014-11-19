//
//  Profile.m
//  TodoLite7
//
//  Created by Chris Anderson on 11/15/13.
//  Copyright (c) 2013 Chris Anderson. All rights reserved.
//

#import "Profile.h"

#define kProfileDocType @"profile"
#define kPrefProfileDocId @"MyProfileDocID"

@implementation Profile

@dynamic user_id, name, type;

// Returns a query for all the profiles in a database.
+ (CBLQuery*) queryProfilesInDatabase: (CBLDatabase*)db {
    CBLView* view = [db viewNamed: @"profiles"];
    if (!view.mapBlock) {
        // Register the map function, the first time we access the view:
        [view setMapBlock: MAPBLOCK({
            if ([doc[@"type"] isEqualToString:kProfileDocType])
                emit(doc[@"name"], nil);
        }) reduceBlock: nil version: @"1"]; // bump version any time you change the MAPBLOCK body!
    }
    return [view createQuery];
}

+ (instancetype) profileInDatabase: (CBLDatabase*)db forExistingUserId: (NSString*)userId {
    NSParameterAssert(userId);
    NSString* profileDocId = [@"p:" stringByAppendingString:userId];
    CBLDocument *doc;
    if (profileDocId.length > 0)
        doc = [db existingDocumentWithID: profileDocId];
    return doc ? [Profile modelForDocument: doc] : nil;
}

+ (instancetype) profileInDatabase: (CBLDatabase*)database forNewUserId: (NSString*)userId name: (NSString*)name {
    NSParameterAssert(name);
    NSParameterAssert(userId);

    CBLDocument* doc = [database documentWithID: [@"p:" stringByAppendingString:userId]];
    Profile* profile = [Profile modelForDocument:doc];
    profile.type = kProfileDocType;
    profile.name = name;
    profile.user_id = userId;
    return profile;
}

- (NSString*) description {
    return [NSString stringWithFormat: @"%@[%@ '%@']", self.class, self.document.abbreviatedID, self.user_id];
}

@end
