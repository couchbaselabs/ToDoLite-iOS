//
//  LoginViewController.m
//  ToDoLite
//
//  Created by Pasin Suriyentrakorn on 10/13/14.
//  Copyright (c) 2014 Pasin Suriyentrakorn. All rights reserved.
//

#import "LoginViewController.h"
#import "AppDelegate.h"

@interface LoginViewController ()

@end

@implementation LoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (self.skipLogin) {
        [self start];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Navigation
- (void)start {
    [self performSegueWithIdentifier:@"start" sender:self];
}

#pragma mark - Buttons


@end
