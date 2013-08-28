//
//  List.h
//  ToDo Lite
//
//  Created by Jens Alfke on 8/22/13.
//
//

#import "Titled.h"
@class Task;


/** A list of Tasks. (See Titled for inherited properties!) */
@interface List : Titled

/** Returns a query for all the lists in a database. */
+ (CBLQuery*) queryListsInDatabase: (CBLDatabase*)db;

/** Returns a query for this list's tasks, in reverse chronological order. */
- (CBLQuery*) queryTasks;

/** Creates a new task. */
- (Task*) addTaskWithTitle: (NSString*)title;

@end
