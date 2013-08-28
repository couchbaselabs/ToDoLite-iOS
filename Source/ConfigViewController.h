//
//  ConfigViewController.h
//  ToDoLite
//
//  Created by Jens Alfke on 8/8/11.
//  Copyright 2011-2013 Couchbase, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
@class CBLServer;


#define kPrefServerDB @"serverDbURL"


/** View controller that lets the user enter a URL to sync with. */
@interface ConfigViewController : UIViewController

- (instancetype) initWithURL: (NSURL*)syncURL;

@property (nonatomic) IBOutlet UITextField* urlField;
@property (nonatomic) IBOutlet UILabel* versionField;
@property (nonatomic) IBOutlet UISwitch* autoSyncSwitch;

- (IBAction) learnMore:(id)sender;
- (IBAction)done:(id)sender;

@end
