//
//  ShareViewController.h
//  TodoLite7
//
//  Created by Chris Anderson on 11/14/13.
//  Copyright (c) 2013 Chris Anderson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Couchbaselite/CBLUITableSource.h>
@class List;

@interface ShareViewController : UIViewController
@property (strong, nonatomic) IBOutlet CBLUITableSource *dataSource;
@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) List *list;
- (void)setList:(List *) newList;
@end
