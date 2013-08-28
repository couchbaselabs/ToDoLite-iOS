//
//  Titled.m
//  ToDoLite
//
//  Created by Jens Alfke on 8/26/13.
//
//

#import "Titled.h"


// Note: See Schema.md for the document schema we're using.


@interface Titled ()
@property (readwrite) NSDate* created_at; // internally make it settable
@end


@implementation Titled


// These properties will be hooked up at runtime by CBLModel to map to the document properties.
@dynamic title, created_at;


// Subclasses must override this to return the value of their documents' "type" property.
+ (NSString*) docType {
    NSAssert(NO, @"Unimplemented method +[%@ docType]", [self class]);
    return nil;
}


// Designated initializer.
- (instancetype) initInDatabase: (CBLDatabase*)database
                      withTitle: (NSString*)title
{
    NSParameterAssert(title);
    self = [super initWithNewDocumentInDatabase: database];
    if (self) {
        // The "type" property identifies what type of document this is.
        // It's used in map functions and by the CBLModelFactory.
        [self setValue: [[self class] docType] ofProperty: @"type"];
        self.title = title;
        self.created_at = [NSDate date];
    }
    return self;
}


// Include the title in the description to make it more informative. */
- (NSString*) description {
    return [NSString stringWithFormat: @"%@[%@ '%@']",
            self.class, self.document.abbreviatedID, self.title];
}


@end
