//
//  NSString+Additions.m
//  ToDoLite
//
//  Created by Pasin Suriyentrakorn on 10/13/14.
//  Copyright (c) 2014 Pasin Suriyentrakorn. All rights reserved.
//

#import "NSString+Additions.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSString (Additions)

- (NSString *)MD5 {
    const char *ptr = [self UTF8String];

    unsigned char buffer[CC_MD5_DIGEST_LENGTH];

    CC_MD5(ptr, (CC_LONG)[self lengthOfBytesUsingEncoding:NSUTF8StringEncoding], buffer);

    NSMutableString *result = [NSMutableString string];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [result appendFormat:@"%02x", buffer[i]];
    }

    return result;
}

@end
