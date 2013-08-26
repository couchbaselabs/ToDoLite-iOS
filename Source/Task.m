//
//  Task.m
//  CouchbaseLists
//
//  Created by Jens Alfke on 8/22/13.
//
//

#import "Task.h"
#import "List.h"


@implementation Task


@dynamic title, check, created_at, listId;


- (instancetype) initInList: (List*)list
                  withTitle: (NSString*)title
{
    NSAssert(list, @"Task must have a list");
    CBLDatabase* db = list.document.database;
    self = [super initWithNewDocumentInDatabase: db];
    if (self) {
        [self setValue: @"item" ofProperty: @"type"];
        self.title = title;
        self.created_at = [NSDate date];
        self.listId = list;
    }
    return self;
}


- (NSString*) description {
    return [NSString stringWithFormat: @"%@[%@ '%@']",
            self.class, self.document.abbreviatedID, self.title];
}


@end
