//
//  MasterController.h
//  ToDo Lite
//
//  Created by Jens Alfke on 8/23/13.
//
//

#import <UIKit/UIKit.h>
#import <Couchbaselite/CBLUITableSource.h>
@class ListController, CBLDatabase;


/** The top-level controller. Shows a list of list names and lets the user select a list. */
@interface MasterController : UIViewController <CBLUITableDelegate>

@property ListController* listController;

- (id)initWithDatabase: (CBLDatabase*)db;

@property (nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic) IBOutlet CBLUITableSource* dataSource;

@end
