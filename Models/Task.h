//
//  Task.h
//  ToDo Lite
//
//  Created by Jens Alfke on 8/22/13.
//
//

#import "Titled.h"
@class List;


/** Model object for a task item. (See Titled for inherited properties!) */
@interface Task : Titled

/** Creates a new Task in the given list, with the given title. */
- (instancetype) initInList: (List*)list
                  withTitle: (NSString*)title;

/** Is the task checked off / completed? */
@property bool checked;

/** The List this item belongs to. */
@property (weak) List* list_id;

@end
