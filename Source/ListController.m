//
//  ListController.m
//  ToDoLite
//
//  Created by Jan Lehnardt on 27/11/2010.
//  Copyright 2011-2013 Couchbase, Inc.
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

#import "ListController.h"
#import "ConfigViewController.h"
#import "AppDelegate.h"
#import "List.h"
#import "Task.h"

#import <Couchbaselite/CouchbaseLite.h>
#import <CouchbaseLite/CBLJSON.h>


@interface ListController ()
@property(nonatomic, strong)CBLDatabase *database;
@property(nonatomic, strong)NSURL* remoteSyncURL;
@property (strong, nonatomic) UIPopoverController *masterPopoverController;
@end


@implementation ListController
{
    List* _currentList;

    IBOutlet UITextField *addItemTextField;
    IBOutlet UIImageView *addItemBackground;
}


#pragma mark - View lifecycle


- (void)viewDidLoad {
    [super viewDidLoad];

    UIBarButtonItem* cleanButton = [[UIBarButtonItem alloc] initWithTitle: @"Clean"
                                                            style: UIBarButtonItemStylePlain
                                                           target: self 
                                                           action: @selector(deleteCheckedItems:)];
    self.navigationItem.rightBarButtonItem = cleanButton;

    [self.tableView setBackgroundView:nil];
    [self.tableView setBackgroundColor:[UIColor clearColor]];

    NSAssert(_database!=nil, @"Not hooked up to database yet");

    self.dataSource.labelProperty = @"title";    // Document property to display in the cell label
    [self updateQuery];
}


static void setViewMargin(UIView* view, CGFloat margin) {
    CGRect superBounds = view.superview.bounds;
    CGRect frame = view.frame;
    frame.origin.x = CGRectGetMinX(superBounds) + margin;
    frame.size.width += (CGRectGetMaxX(superBounds) - margin) - CGRectGetMaxX(frame);
    view.frame = frame;
}


- (void) viewDidLayoutSubviews {
    if(gRunningOnIPad) {
        // Adjust left/right margins of New Item text field when nib is scaled to iPad:
        setViewMargin(addItemBackground, 44);
        setViewMargin(addItemTextField, 55);
    }
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
}


- (void) setCurrentList:(List *)list {
    if (list == _currentList)
        return;
    _currentList = list;
    [self updateQuery];

    if (self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }
}


- (void) updateQuery {
    if (_dataSource)
        _dataSource.query = [[_currentList queryTasks] asLiveQuery];
    self.title = _currentList.title;
}


#pragma mark - TABLE DELEGATE


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50;
}


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

    UILabel* textLabel = cell.textLabel;
    textLabel.backgroundColor = [UIColor clearColor];
    textLabel.font = [UIFont fontWithName: @"Marker Felt" size:24.0];
    textLabel.minimumScaleFactor = 0.75;
    textLabel.adjustsFontSizeToFitWidth = YES;

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


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CBLQueryRow *row = [self.dataSource rowAtIndex:indexPath.row];
    Task* task = [Task modelForDocument: row.document];

    // Toggle the document's 'checked' property:
    task.check = !task.check;

    // Save changes:
    NSError* error;
    if (![task save: &error]) {
        [gAppDelegate showAlert: @"Failed to update item" error: error fatal: NO];
    }
}


#pragma mark - EDITING


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
        [gAppDelegate showAlert: @"Failed to delete items" error: error fatal: NO];
    }
}

#pragma mark - TEXT FIELD


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
        [gAppDelegate showAlert: @"Couldn't save new item" error: error fatal: NO];
    }
}


#pragma mark - SPLIT VIEW:


- (void)splitViewController:(UISplitViewController *)splitController
     willHideViewController:(UIViewController *)viewController
          withBarButtonItem:(UIBarButtonItem *)barButtonItem
       forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = NSLocalizedString(@"Lists", @"Lists");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController
     willShowViewController:(UIViewController *)viewController
  invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}


@end
