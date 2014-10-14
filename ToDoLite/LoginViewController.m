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
    
    if (self.shouldSkipLogin) {
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

- (IBAction)facebookLoginAction:(id)sender {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    [app loginWithFacebook:^(BOOL success, NSError *error) {
        if (success) {
            [self start];
        } else {
            [app showMessage:@"Facebook Login Error. Please try again." withTitle:@"Error"];
        }
    }];
}

- (IBAction)loginAsGuestAction:(id)sender {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    [app loginAsGuest];
    [self start];
}

@end
