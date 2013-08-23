//
//  Task.h
//  CouchbaseLists
//
//  Created by Jens Alfke on 8/22/13.
//
//

#import <CouchbaseLite/CouchbaseLite.h>
@class List;


/** Model object for a task item. */
@interface Task : CBLModel

@property (copy) NSString* title;
@property bool check;
@property NSDate* created_at;
@property (weak) List* listId;

/** Creates a new Task in the database, with the given text. */
- (instancetype) initInList: (List*)list
                  withTitle: (NSString*)title;

@end
