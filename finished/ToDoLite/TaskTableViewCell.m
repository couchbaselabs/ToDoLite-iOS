//
//  TaskTableViewCell.m
//  ToDoLite
//
//  Created by Pasin Suriyentrakorn on 4/8/14.
//  Copyright (c) 2014 Chris Anderson. All rights reserved.
//

#import "TaskTableViewCell.h"
#import "Task.h"

@implementation TaskTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        
    }
    return self;
}

- (void)awakeFromNib {
    
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
}

- (void)setTask:(Task *)task {
    _task = task;
    
    self.name.text = task.title;
    
    bool checked = task.checked;
    self.name.textColor = checked ? [UIColor grayColor] : [UIColor blackColor];
    if (checked) {
        self.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        self.accessoryType = UITableViewCellAccessoryNone;
    }
    
    NSArray *attachments = [task attachmentNames];
    if ([attachments count] > 0) {
        CBLAttachment *attachment = [task attachmentNamed:[attachments objectAtIndex:0]];
        UIImage *attachedImage = [UIImage imageWithData:attachment.content];
        [self.image setImage:attachedImage forState:UIControlStateNormal];
    } else {
        [self.image setImage:[UIImage imageNamed:@"Camera-Light"] forState:UIControlStateNormal];
    }
}

- (IBAction)imageButtonAction:(id)sender {
    if ([self.delegate respondsToSelector:@selector(didSelectImageButton:ofTask:)]) {
        [self.delegate didSelectImageButton:(UIButton *)sender ofTask:self.task];
    }
}

@end
