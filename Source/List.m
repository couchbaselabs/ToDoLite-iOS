//
//  List.m
//  CouchbaseLists
//
//  Created by Jens Alfke on 8/22/13.
//
//

#import "List.h"
#import "Task.h"

@implementation List


@dynamic title, created_at;


+ (CBLQuery*) queryListsInDatabase: (CBLDatabase*)db {
    CBLView* view = [db viewNamed: @"lists"];
    if (!view.mapBlock) {
        [view setMapBlock: MAPBLOCK({
            if ([doc[@"type"] isEqualToString: @"list"])
                emit(doc[@"title"], nil);
        }) reduceBlock: nil version: @"1"];
    }
    return [view query];
}


- (instancetype) initInDatabase: (CBLDatabase*)db
                      withTitle: (NSString*)title
{
    self = [super initWithNewDocumentInDatabase: db];
    if (self) {
        [self setValue: @"list" ofProperty: @"type"];
        self.title = title;
        self.created_at = [NSDate date];
    }
    return self;
}


- (Task*) addTaskWithTitle: (NSString*)title {
    return [[Task alloc] initInList: self withTitle: title];
}


- (CBLQuery*) queryTasks {
    CBLView* view = [self.document.database viewNamed: @"tasksByDate"];
    if (!view.mapBlock) {
        [view setMapBlock: MAPBLOCK({
            if ([doc[@"type"] isEqualToString: @"item"]) {
                id date = doc[@"created_at"];
                NSString* listID = doc[@"listId"];
                emit(@[listID, date], doc);
            }
        }) reduceBlock: nil version: @"3"];
    }
    CBLQuery* query = [view query];
    query.descending = YES;
    NSString* myListId = self.document.documentID;
    query.startKey = @[myListId, @{}];
    query.endKey = @[myListId];
    return query;
}



@end
