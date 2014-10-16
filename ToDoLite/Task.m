//
//  Task.m
//  ToDo Lite
//
//  Created by Jens Alfke on 8/22/13.
//
//

#import "Task.h"
#import "List.h"

#define kTaskDocType @"task"
#define kTaskImageName @"image"

@implementation Task

@dynamic checked, list_id;

+ (NSString*) docType {
    return kTaskDocType;
}

- (instancetype) initInList: (List*)list
                  withTitle: (NSString*)title
                  withImage: (NSData*)image
       withImageContentType: (NSString*)contentType {
    NSAssert(list, @"Task must have a list");
    self = [super initInDatabase: list.document.database withTitle: title];
    if (self) {
        self.list_id = list;
        
        if (image) {
            [self setAttachmentNamed:kTaskImageName withContentType:contentType content:image];
        }
    }
    return self;
}

- (void) setImage: (NSData*)image contentType: (NSString*)contentType {
    [self setAttachmentNamed:kTaskImageName withContentType:contentType content:image];
}

@end
