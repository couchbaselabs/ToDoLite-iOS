//
//  DetailViewController.h
//  ToDoLite
//
//  Created by Pasin Suriyentrakorn on 10/11/14.
//  Copyright (c) 2014 Pasin Suriyentrakorn. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CouchbaseLite/CouchbaseLite.h>
#import "List.h"
#import "RoundedButton.h"
#import "TaskTableViewCell.h"

@interface DetailViewController : UIViewController <UITableViewDelegate, TaskTableViewCellDelegate,
UITextFieldDelegate, UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (strong, nonatomic) List *list;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UITextField *addItemTextField;
@property (weak, nonatomic) IBOutlet RoundedButton *addImageButton;

@end

