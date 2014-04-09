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
#import "TaskTableViewCell.h"

@interface DetailViewController : UIViewController
<
CBLUITableDelegate,
UISplitViewControllerDelegate,
UITextFieldDelegate,
UIActionSheetDelegate,
UIImagePickerControllerDelegate,
UINavigationControllerDelegate,
TaskTableViewCellDelegate
>

@property (strong, nonatomic) List *detailItem;

@property (nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic) IBOutlet CBLUITableSource *dataSource;
@property (weak, nonatomic) IBOutlet UITextField *addItemTextField;
@property (weak, nonatomic) IBOutlet UIButton *addImageButton;

- (IBAction)shareButtonAction:(id)sender;
- (IBAction)addImageButtonAction:(id)sender;
- (void)setDetailItem:(List*)newDetailItem;

@end
