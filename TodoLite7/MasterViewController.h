//
//  MasterViewController.h
//  TodoLite7
//
//  Created by Chris Anderson on 11/14/13.
//  Copyright (c) 2013 Chris Anderson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Couchbaselite/CBLUITableSource.h>

@class DetailViewController;

@interface MasterViewController : UIViewController <CBLUITableDelegate>

@property (strong, nonatomic) DetailViewController *detailViewController;
@property (nonatomic) IBOutlet CBLUITableSource* dataSource;
@property (strong, nonatomic) IBOutlet UITableView *tableView;

@end
