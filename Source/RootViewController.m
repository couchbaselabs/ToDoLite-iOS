//
//  RootViewController.m
//  Couchbase Lists
//
//  Created by Jan Lehnardt on 27/11/2010.
//  Copyright 2011 Couchbase, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not
// use this file except in compliance with the License. You may obtain a copy of
// the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations under
// the License.
//

#import "RootViewController.h"
#import "ConfigViewController.h"
#import "DemoAppDelegate.h"
#import "List.h"
#import "Task.h"

#import <Couchbaselite/CouchbaseLite.h>
#import <CouchbaseLite/CBLJSON.h>


@interface RootViewController ()
@property(nonatomic, strong)CBLDatabase *database;
@property(nonatomic, strong)NSURL* remoteSyncURL;
- (void)updateSyncURL;
- (void)showSyncButton;
- (void)showSyncStatus;
- (IBAction)configureSync:(id)sender;
- (void)forgetSync;
@end


@implementation RootViewController
{
    CBLReplication* _pull;
    CBLReplication* _push;
    BOOL _showingSyncButton;
    List* _currentList;

    IBOutlet UIProgressView *progress;
    IBOutlet UITextField *addItemTextField;
    IBOutlet UIImageView *addItemBackground;
}


#pragma mark - View lifecycle


- (void)viewDidLoad {
    [super viewDidLoad];

    UIBarButtonItem* deleteButton = [[UIBarButtonItem alloc] initWithTitle: @"Clean"
                                                            style:UIBarButtonItemStylePlain
                                                           target: self 
                                                           action: @selector(deleteCheckedItems:)];
    self.navigationItem.leftBarButtonItem = deleteButton;
    
    [self showSyncButton];
    
    [self.tableView setBackgroundView:nil];
    [self.tableView setBackgroundColor:[UIColor clearColor]];
    if([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        [addItemBackground setFrame:CGRectMake(45, 8, 680, 44)];
        [addItemTextField setFrame:CGRectMake(56, 8, 665, 43)];
    }

    NSAssert(_database!=nil, @"Not hooked up to database yet");

    self.dataSource.labelProperty = @"title";    // Document property to display in the cell label
    [self updateQuery];

    [self updateSyncURL];
}


- (void)dealloc {
    [self forgetSync];
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    // Check for changes after returning from the sync config view:
    [self updateSyncURL];
}


- (void)showErrorAlert: (NSString*)message forError: (NSError*)error {
    NSLog(@"%@: error=%@", message, error);
    [(DemoAppDelegate*)[[UIApplication sharedApplication] delegate]
     showAlert: message error: error fatal: NO];
}


- (void)useDatabase:(CBLDatabase*)theDatabase {
    self.database = theDatabase;

    // Register a validation function requiring parseable dates:
    [theDatabase defineValidation: @"created_at" asBlock: VALIDATIONBLOCK({
        if (newRevision.isDeleted)
            return YES;
        id date = [newRevision.properties objectForKey: @"created_at"];
        if (date && ! [CBLJSON dateWithJSONObject: date]) {
            context.errorMessage = [@"invalid date " stringByAppendingString: [date description]];
            return NO;
        }
        return YES;
    })];

    [[_database modelFactory] registerClass: [List class] forDocumentType: @"list"];
    [[_database modelFactory] registerClass: [Task class] forDocumentType: @"item"];

    List* list;
    CBLQuery *query = [List queryListsInDatabase: _database];
    CBLQueryRow* row = query.rows.nextRow;
    if (row) {
        list = [List modelForDocument: row.document];
    } else {
        // There are no lists in the database, so create one:
        NSLog(@"No lists found; creating initial one");
        List* firstList = [[List alloc] initInDatabase: _database withTitle: @"To Do"];
        NSError* error;
        if (![firstList save: &error]) {
            [self showErrorAlert: @"create a list" forError: error];
            return;
        }
    }
    self.currentList = list;
}


- (void) setCurrentList:(List *)list {
    if (list == _currentList)
        return;
    _currentList = list;
    [self updateQuery];
}


- (void) updateQuery {
    if (_dataSource)
        _dataSource.query = [[_currentList queryTasks] asLiveQuery];
    self.title = _currentList.title;
}


#pragma mark - Couch table source delegate


// Customize the appearance of table view cells.
- (void)couchTableSource:(CBLUITableSource*)source
             willUseCell:(UITableViewCell*)cell
                  forRow:(CBLQueryRow*)row
{
    // Set the cell background and font:
    static UIColor* kBGColor;
    if (!kBGColor)
        kBGColor = [UIColor colorWithPatternImage: [UIImage imageNamed:@"item_background"]];
    cell.backgroundColor = kBGColor;
    cell.selectionStyle = UITableViewCellSelectionStyleGray;

    cell.textLabel.font = [UIFont fontWithName: @"Helvetica" size:18.0];
    cell.textLabel.backgroundColor = [UIColor clearColor];
    
    // Configure the cell contents.
    // cell.textLabel.text is already set, thanks to setting up labelProperty above.
    Task* task = [Task modelForDocument: row.document];
    bool checked = task.check;
    cell.textLabel.textColor = checked ? [UIColor grayColor]
                                       : [UIColor blackColor];
    cell.imageView.image = [UIImage imageNamed:
            (checked ? @"list_area___checkbox___checked"
                     : @"list_area___checkbox___unchecked")];
}


#pragma mark - Table view delegate


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CBLQueryRow *row = [self.dataSource rowAtIndex:indexPath.row];
    Task* task = [Task modelForDocument: row.document];

    // Toggle the document's 'checked' property:
    task.check = !task.check;

    // Save changes:
    NSError* error;
    if (![task save: &error]) {
        [self showErrorAlert: @"Failed to update item" forError: error];
    }
}


#pragma mark - Editing:


- (NSArray*)checkedDocuments {
    // If there were a whole lot of documents, this would be more efficient with a custom query.
    NSMutableArray* checked = [NSMutableArray array];
    for (CBLQueryRow* row in self.dataSource.rows) {
        Task* task = [Task modelForDocument: row.document];
        if (task.check)
            [checked addObject: task.document];
    }
    return checked;
}


- (IBAction)deleteCheckedItems:(id)sender {
    NSUInteger numChecked = self.checkedDocuments.count;
    if (numChecked == 0)
        return;
    NSString* message = [NSString stringWithFormat: @"Are you sure you want to remove the %u"
                                                     " checked-off item%@?",
                                                     numChecked, (numChecked==1 ? @"" : @"s")];
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle: @"Remove Completed Items?"
                                                    message: message
                                                   delegate: self
                                          cancelButtonTitle: @"Cancel"
                                          otherButtonTitles: @"Remove", nil];
    [alert show];
}


- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0)
        return;
    NSError* error;
    if (![_dataSource deleteDocuments: self.checkedDocuments error: &error]) {
        [self showErrorAlert: @"Failed to delete items" forError: error];
    }
}

#pragma mark - UITextField delegate


- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
    [addItemBackground setImage:[UIImage imageNamed:@"textfield___inactive.png"]];

	return YES;
}


- (void)textFieldDidBeginEditing:(UITextField *)textField {
    [addItemBackground setImage:[UIImage imageNamed:@"textfield___active.png"]];
}


-(void)textFieldDidEndEditing:(UITextField *)textField {
    // Get the name of the item from the text field:
	NSString *title = addItemTextField.text;
    if (title.length == 0) {
        return;
    }
    [addItemTextField setText:nil];

    // Create and save a new task:
    NSAssert(_currentList, @"no current list");
    Task* task = [_currentList addTaskWithTitle: title];
    NSError* error;
    if (![task save: &error]) {
        [self showErrorAlert: @"Couldn't save new item" forError: error];
    }
}


#pragma mark - SYNC:


- (IBAction)configureSync:(id)sender {
    UINavigationController* navController = (UINavigationController*)self.parentViewController;
    ConfigViewController* controller = [[ConfigViewController alloc] init];
    [navController pushViewController: controller animated: YES];
}


- (void)updateSyncURL {
    if (!_database)
        return;
    NSURL* newRemoteURL = nil;
    NSString *syncpoint = [[NSUserDefaults standardUserDefaults] objectForKey:@"syncpoint"];
    if (syncpoint.length > 0)
        newRemoteURL = [NSURL URLWithString:syncpoint];
    
    [self forgetSync];

    NSArray* repls = [_database replicateWithURL: newRemoteURL exclusively: YES];
    if (repls) {
        _pull = [repls objectAtIndex: 0];
        _push = [repls objectAtIndex: 1];
        _pull.continuous = _push.continuous = YES;
        _pull.persistent = _push.persistent = NO;
        _push.create_target = YES;
        NSNotificationCenter* nctr = [NSNotificationCenter defaultCenter];
        [nctr addObserver: self selector: @selector(replicationProgress:)
                     name: kCBLReplicationChangeNotification object: _pull];
        [nctr addObserver: self selector: @selector(replicationProgress:)
                     name: kCBLReplicationChangeNotification object: _push];
    }
}


- (void) forgetSync {
    NSNotificationCenter* nctr = [NSNotificationCenter defaultCenter];
    if (_pull) {
        [nctr removeObserver: self name: nil object: _pull];
        _pull = nil;
    }
    if (_push) {
        [nctr removeObserver: self name: nil object: _push];
        _push = nil;
    }
}


- (void)showSyncButton {
    if (!_showingSyncButton) {
        _showingSyncButton = YES;
        UIBarButtonItem* syncButton =
                [[UIBarButtonItem alloc] initWithTitle: @"Configure"
                                                 style:UIBarButtonItemStylePlain
                                                target: self 
                                                action: @selector(configureSync:)];
        self.navigationItem.rightBarButtonItem = syncButton;
    }
}


- (void)showSyncStatus {
    if (_showingSyncButton) {
        _showingSyncButton = NO;
        if (!progress) {
            progress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
            CGRect frame = progress.frame;
            frame.size.width = self.view.frame.size.width / 4.0f;
            progress.frame = frame;
        }
        UIBarButtonItem* progressItem = [[UIBarButtonItem alloc] initWithCustomView:progress];
        progressItem.enabled = NO;
        self.navigationItem.rightBarButtonItem = progressItem;
    }
}


- (void) replicationProgress: (NSNotificationCenter*)n {
    if (_pull.mode == kCBLReplicationActive || _push.mode == kCBLReplicationActive) {
        unsigned completed = _pull.completed + _push.completed;
        unsigned total = _pull.total + _push.total;
        NSLog(@"SYNC progress: %u / %u", completed, total);
        [self showSyncStatus];
        progress.progress = (completed / (float)MAX(total, 1u));
    } else {
        [self showSyncButton];
    }
}


@end
