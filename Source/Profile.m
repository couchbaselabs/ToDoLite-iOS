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

+ (instancetype) currentUserProfile: (CBLDatabase*)db {
    NSString* userId = [[NSUserDefaults standardUserDefaults] objectForKey: @"CBLFBUserID"];
    if (userId) {
        NSString* profileDocId = [@"p:" stringByAppendingString:userId];
        CBLDocument *doc;
        if (profileDocId.length > 0)
            doc = [db documentWithID: profileDocId];
        return doc ? [Profile modelForDocument: doc] : nil;
    } else {
        return nil;
    }
}



- (instancetype) initCurrentUserProfileInDatabase: (CBLDatabase*)database
                       withName: (NSString*)name
                       andUserId: (NSString*)userId
{
    NSParameterAssert(name);
    NSParameterAssert(userId);

    CBLDocument* doc = [database documentWithID: [@"p:" stringByAppendingString:userId]];

    self = [super initWithDocument:doc];
    if (self) {
        self.name = name;
        self.user_id = userId;
        self.type = kProfileDocType;
    }
    return self;
}



// Include the title in the description to make it more informative. */
- (NSString*) description {
    return [NSString stringWithFormat: @"%@[%@ '%@']",
            self.class, self.document.abbreviatedID, self.user_id];
}


@end
