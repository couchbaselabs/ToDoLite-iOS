//
//  TaskTableViewCell.h
//  ToDoLite
//
//  Created by Pasin Suriyentrakorn on 4/8/14.
//  Copyright (c) 2014 Chris Anderson. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Task;

@protocol TaskTableViewCellDelegate;

@interface TaskTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIButton *image;
@property (weak, nonatomic) IBOutlet UILabel *name;

@property (strong, nonatomic) Task *task;
@property (weak, nonatomic) id <TaskTableViewCellDelegate> delegate;

- (IBAction)imageButtonAction:(id)sender;

@end

@protocol TaskTableViewCellDelegate <NSObject>
- (void)didSelectImageButton:(UIButton *)imageButton ofTask:(Task *)task;
@end
