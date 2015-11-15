//
//  Titled.h
//  ToDoLite
//
//  Created by Jens Alfke on 8/26/13.
//
//

#import <CouchbaseLite/CouchbaseLite.h>

/** Abstract superclass of List and Task. A generic model object with a title and creation date. */
@interface Titled : CBLModel

/** The "type" property value for documents that belong to this class. Abstract. */
+ (NSString*) docType;

@end
