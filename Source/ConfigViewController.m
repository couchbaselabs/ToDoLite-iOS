//
//  ConfigViewController.m
//  CouchDemo
//
//  Created by Jens Alfke on 8/8/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "ConfigViewController.h"

@implementation ConfigViewController


@synthesize urlField, autoSyncSwitch;


- (id)init {
    self = [super initWithNibName: @"ConfigViewController" bundle: nil];
    if (self) {
        // Custom initialization
        self.navigationItem.title = @"Configure Sync";

        UIBarButtonItem* purgeButton = [[UIBarButtonItem alloc] initWithTitle: @"Done"
                                                                style:UIBarButtonItemStyleDone
                                                               target: self 
                                                               action: @selector(done:)];
        self.navigationItem.leftBarButtonItem = [purgeButton autorelease];
    }
    return self;
}


#pragma mark - View lifecycle


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    NSString *syncpoint = [[NSUserDefaults standardUserDefaults] objectForKey:@"syncpoint"];
    self.urlField.text = syncpoint;
}


- (IBAction)learnMore:(id)sender {
    static NSString* const kLearnMoreURLs[] = {
        @"http://www.couchbase.com/products-and-services/couchbase-single-server",
        @"http://couchdb.apache.org/",
        @"http://www.iriscouch.com/"
    };
    NSURL* url = [NSURL URLWithString: kLearnMoreURLs[[sender tag]]];
    [[UIApplication sharedApplication] openURL: url];
}


- (void)pop {
    
    UINavigationController* navController = (UINavigationController*)self.parentViewController;
    [navController popViewControllerAnimated: YES];
}


- (IBAction)done:(id)sender {
    NSString* syncpoint = self.urlField.text;
    if (syncpoint.length > 0) {
        NSURL *remoteURL = [NSURL URLWithString:syncpoint];
        if (!remoteURL || ![remoteURL.scheme hasPrefix: @"http"]) {
            // Oops, not a valid URL:
            NSString* message = @"You entered an invalid URL. Do you want to fix it or revert back to what it was before?";
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle: @"Invalid URL"
                                                            message: message
                                                           delegate: self
                                                  cancelButtonTitle: @"Fix It"
                                                  otherButtonTitles: @"Revert", nil];
            [alert show];
            [alert release];
            return;
        }
        
        // If user just enters the server URL, fill in a default database name:
        if ([remoteURL.path isEqual: @""] || [remoteURL.path isEqual: @"/"]) {
            remoteURL = [remoteURL URLByAppendingPathComponent: @"grocery-sync"];
            syncpoint = remoteURL.absoluteString;
        }        
    }
    [[NSUserDefaults standardUserDefaults] setObject: syncpoint forKey:@"syncpoint"];
    [self pop];
}


- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex > 0) {
        [self pop]; // Go back to the main screen without saving the URL
    }
}


@end