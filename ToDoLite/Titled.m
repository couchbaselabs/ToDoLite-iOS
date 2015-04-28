//
//  Titled.m
//  ToDoLite
//
//  Created by Jens Alfke on 8/26/13.
//
//

#import "Titled.h"

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

- (void)awakeFromInitializer {
    self.type = [[self class] docType];
    self.created_at = [NSDate date];
}

- (NSString*) description {
    return [NSString stringWithFormat: @"%@[%@ '%@']",
            self.class, self.document.abbreviatedID, self.title];
}

@end
