//
//  ReplaceRootViewControllerSegue.m
//  ToDoLite
//
//  Created by Pasin Suriyentrakorn on 10/13/14.
//  Copyright (c) 2014 Pasin Suriyentrakorn. All rights reserved.
//

#import "ReplaceRootViewControllerSegue.h"
#import "AppDelegate.h"

@implementation ReplaceRootViewControllerSegue : UIStoryboardSegue

- (void)perform {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    app.window.rootViewController = self.destinationViewController;
}

@end
