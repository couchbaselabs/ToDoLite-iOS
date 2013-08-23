//
//  List.h
//  CouchbaseLists
//
//  Created by Jens Alfke on 8/22/13.
//
//

#import <CouchbaseLite/CouchbaseLite.h>
@class Task;


/** A list of Tasks. */
@interface List : CBLModel

+ (CBLQuery*) queryListsInDatabase: (CBLDatabase*)db;

- (instancetype) initInDatabase: (CBLDatabase*)db
                      withTitle: (NSString*)title;

@property (copy) NSString* title;
@property NSDate* created_at;

- (CBLQuery*) queryTasks;

- (Task*) addTaskWithTitle: (NSString*)title;

@end
