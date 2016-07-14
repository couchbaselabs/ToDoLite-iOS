//
//  LoginViewController.m
//  ToDoLite
//
//  Created by Pasin Suriyentrakorn on 10/13/14.
//  Copyright (c) 2014 Pasin Suriyentrakorn. All rights reserved.
//

#import "LoginViewController.h"
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>
#import "AppDelegate.h"

@interface LoginViewController ()

@property (nonatomic) FBSDKLoginManager *facebookLoginManager;
@property (nonatomic) UIAlertView *facebookLoginAlertView;

@end

@implementation LoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Buttons

- (IBAction)facebookLoginAction:(id)sender {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    [self loginWithFacebook:^(BOOL success, NSError *error) {
        if (success) {
            [self start];
        } else {
            [app showMessage:@"Facebook Login Error. Please try again." withTitle:@"Error"];
        }
    }];
}

- (IBAction)loginAsGuestAction:(id)sender {
    if ([self.delegate respondsToSelector:@selector(didLogInAsGuest)])
        [self.delegate didLogInAsGuest];
    [self start];
}

#pragma mark - Navigation

- (void)start {
    [self performSegueWithIdentifier:@"start" sender:self];
}


#pragma mark - Application Level Setup

+ (BOOL)application:(UIApplication *)application
   didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    return [[FBSDKApplicationDelegate sharedInstance] application:application
                                    didFinishLaunchingWithOptions:launchOptions];
}

+ (BOOL)application:(UIApplication *)application openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    return [[FBSDKApplicationDelegate sharedInstance] application:application
                                                          openURL:url
                                                sourceApplication:sourceApplication
                                                       annotation:annotation];
}

#pragma mark - Login

- (void)logout {
    if (self.facebookLoginManager) {
        [self unobserveFacebookAccessTokenChange];
        [self.facebookLoginManager logOut];
        self.facebookLoginManager = nil;
    }

    if ([self.delegate respondsToSelector:@selector(didLogout)])
        [self.delegate didLogout];
}

#pragma mark - Facebook

- (FBSDKLoginManager *)facebookLoginManager {
    if (!_facebookLoginManager)
        _facebookLoginManager = [[FBSDKLoginManager alloc] init];
    return _facebookLoginManager;
}

- (void)loginWithFacebook:(void (^)(BOOL success, NSError *error))resultBlock {
    [self.facebookLoginManager logInWithReadPermissions:@[@"email"]
                                     fromViewController:self
                                                handler:
     ^(FBSDKLoginManagerLoginResult *loginResult, NSError *error) {
         if (error || loginResult.isCancelled) {
             resultBlock(NO, error);
         } else {
             [[[FBSDKGraphRequest alloc] initWithGraphPath:@"me"
                                                parameters:@{@"fields": @"name"}]
              startWithCompletionHandler:
              ^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
                  if (!error) {
                      [self observeFacebookAccessTokenChange];
                      [self facebookUserDidLoginWithToken:loginResult.token userInfo:result];
                      resultBlock(YES, nil);
                  } else {
                      [self.facebookLoginManager logOut];
                      resultBlock(NO, error);
                  }
              }];
         }
     }];
}

- (void)facebookUserDidLoginWithToken:(FBSDKAccessToken *)token userInfo:(NSDictionary *)info {
    NSAssert(token, @"Facebook Access Token Data is nil");
    if ([self.delegate respondsToSelector:@selector(didLogInAsFacebookUserId:name:token:)])
        [self.delegate didLogInAsFacebookUserId:token.userID
                                           name:info[@"name"] token:token.tokenString];
}

- (void)observeFacebookAccessTokenChange {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:FBSDKAccessTokenDidChangeNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(facebookAccessTokenChange:)
                                                 name:FBSDKAccessTokenDidChangeNotification
                                               object:nil];
}

- (void)unobserveFacebookAccessTokenChange {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:FBSDKAccessTokenDidChangeNotification
                                                  object:nil];
}

- (void)facebookAccessTokenChange:(NSNotification *)notification {
    NSString *message = @"Facebook Session is expired. "
        "Please login again to review your session.";
    self.facebookLoginAlertView = [[UIAlertView alloc] initWithTitle:@"Facebook"
                                                             message:message
                                                            delegate:self
                                                   cancelButtonTitle:@"OK"
                                                   otherButtonTitles:nil];
    [self.facebookLoginAlertView show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView == self.facebookLoginAlertView) {
        AppDelegate *app = [[UIApplication sharedApplication] delegate];
        [app logout];
    }
}

@end
