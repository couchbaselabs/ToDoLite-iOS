//
//  Titled.m
//  ToDoLite
//
//  Created by Jens Alfke on 8/26/13.
//
//

#import "Titled.h"

@implementation Titled

// Step 2: mark `title` and `created_at` as dynamic

// Subclasses must override this to return the value of their documents' "type" property.
+ (NSString*) docType {
    NSAssert(NO, @"Unimplemented method +[%@ docType]", [self class]);
    return nil;
}

- (void)awakeFromInitializer {
    // Step 2: set the created_at to the current time and the type to the docType method's return
}

@end
