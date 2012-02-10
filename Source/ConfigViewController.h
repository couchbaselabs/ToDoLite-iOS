//
//  ConfigViewController.h
//  CouchDemo
//
//  Created by Jens Alfke on 8/8/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DemoAppDelegate.h"

@class CouchServer;

@interface ConfigViewController : UIViewController

//@property (nonatomic, readonly) IBOutlet UITextField* urlField;
@property (nonatomic, readonly) IBOutlet UILabel* versionField;
@property (nonatomic, readonly) IBOutlet UIButton* pairTrigger;
@property (nonatomic, readonly) IBOutlet UIButton* unpairTrigger;
@property (nonatomic, readonly) IBOutlet UISwitch* autoSyncSwitch;
@property (nonatomic, readonly) DemoAppDelegate *delegate;

- (IBAction) initiatePairing:(id)sender;
- (IBAction) removePairing:(id)sender;
- (IBAction)done:(id)sender;

@end
