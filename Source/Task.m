//
//  Task.m
//  ToDo Lite
//
//  Created by Jens Alfke on 8/22/13.
//
//

#import "Task.h"
#import "List.h"


// Note: See Schema.md for the document schema we're using.


#define kTaskDocType @"task"


@implementation Task


@dynamic checked, list_id;


+ (NSString*) docType {
    return kTaskDocType;
}


- (instancetype) initInList: (List*)list
                  withTitle: (NSString*)title
{
    NSAssert(list, @"Task must have a list");
    self = [super initInDatabase: list.document.database withTitle: title];
    if (self) {
        self.list_id = list;
    }
    return self;
}


@end
