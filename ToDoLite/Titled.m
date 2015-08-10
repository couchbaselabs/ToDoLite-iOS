//
//  Titled.m
//  ToDoLite
//
//  Created by Jens Alfke on 8/26/13.
//
//

#import "Titled.h"

@implementation Titled

@dynamic title, created_at, type;

// Subclasses must override this to return the value of their documents' "type" property.
+ (NSString*) docType {
    NSAssert(NO, @"Unimplemented method +[%@ docType]", [self class]);
    return nil;
}

- (void)awakeFromInitializer {
    self.created_at = [NSDate date];
    self.type = [[self class] docType];
}

@end
