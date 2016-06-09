//
//  LoginViewController.h
//  ToDoLite
//
//  Created by Pasin Suriyentrakorn on 10/13/14.
//  Copyright (c) 2014 Pasin Suriyentrakorn. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol LoginViewControllerDelegate;

@interface LoginViewController : UIViewController

@property id<LoginViewControllerDelegate> delegate;

+ (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions;

+ (BOOL)application:(UIApplication *)application openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication annotation:(id)annotation;

- (void)tryLogin;
- (void)loginAsGuest;
- (void)logout;

@end

@protocol LoginViewControllerDelegate <NSObject>

- (void)didLogInAsGuest;
- (void)didLogInAsFacebookUserId:(NSString *)userId name:(NSString *)name token:(NSString *)token;
- (void)didLogout;

@end
