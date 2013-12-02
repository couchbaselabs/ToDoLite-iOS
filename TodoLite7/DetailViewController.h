//
//  DetailViewController.h
//  TodoLite7
//
//  Created by Chris Anderson on 11/14/13.
//  Copyright (c) 2013 Chris Anderson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Couchbaselite/CBLUITableSource.h>
#import "List.h"

@interface DetailViewController : UIViewController <CBLUITableDelegate,UISplitViewControllerDelegate, UITextFieldDelegate>

@property (strong, nonatomic) List *detailItem;

@property (nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic) IBOutlet CBLUITableSource* dataSource;
@property (weak, nonatomic) IBOutlet UITextField *addItemTextField;

- (void)setDetailItem:(List*)newDetailItem;

- (IBAction) shareButtonAction:(id)sender;
@end
