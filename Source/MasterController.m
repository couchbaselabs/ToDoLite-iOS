//
//  MasterController.m
//  ToDo Lite
//
//  Created by Jens Alfke on 8/23/13.
//
//

#import "MasterController.h"
#import "AppDelegate.h"
#import "ListController.h"
#import "List.h"
#import <CouchbaseLite/CouchbaseLite.h>


// User defaults key whose value is the document ID of the currently-displayed list.
#define kPrefCurrentList @"CurrentListID"


@interface MasterController () <UIAlertViewDelegate>
@end


@implementation MasterController
{
    CBLDatabase* _database;
    CBLLiveQuery* _query;
    BOOL _initialLoadComplete;
    ListController* _listController;
    UIBarButtonItem* _newListButton;
}


// Designated initializer.
- (id)initWithDatabase: (CBLDatabase*)db
{
    NSParameterAssert(db);
    self = [super initWithNibName: @"MasterController_iPhone" bundle: nil];
    if (self) {
        _database = db;
        _query = [List queryListsInDatabase: _database].asLiveQuery;
    }
    return self;
}


// Called immediately after the nib loads; customizes views.
- (void)viewDidLoad
{
    [super viewDidLoad];

    _newListButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                   target:self
                                                                   action:@selector(newList:)];
    self.navigationItem.leftBarButtonItem = _newListButton;

    [self setEditing: NO];
    self.title = @"Lists";

    if (!gRunningOnIPad) {
        UIImage* bgImage = [UIImage imageNamed: @"background.jpg"];
        [_tableView setBackgroundView: [[UIImageView alloc] initWithImage: bgImage]];
    }

    NSAssert(_dataSource, @"_dataSource not connected");
    _dataSource.query = _query;
    _dataSource.labelProperty = @"title";    // Document property to display in the cell label
}


// Called whenever the view will appear onscreen.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    if (!gRunningOnIPad) {
        // On iPhone, when returning to the master view, clear the current-list pref.
        if (_initialLoadComplete)
            self.initialList = nil;
    }
}


// Returns the list that was last showing on quit:
- (List*) initialList {
    CBLDocument* doc = nil;
    NSString* listID = [[NSUserDefaults standardUserDefaults] objectForKey: kPrefCurrentList];
    if (listID) {
        if (listID.length > 0)
            doc = [_database documentWithID: listID];
        return doc ? [List modelForDocument: doc] : nil;
    } else {
        // If there's no pref, choose the first list:
        [_query waitForRows];
        doc = _query.rows.nextRow.document;
        if (doc)
            return [List modelForDocument: doc];

        // If there are no lists, create one:
        NSLog(@"No lists found; creating initial one");
        return [self createListWithTitle: @"To Do"];
    }
}


// Stores a pref to remember which list is currently displayed, so it can be restored on launch.
- (void) setInitialList: (List*)list {
    NSString* docID = list ? list.document.documentID : @"";
    [[NSUserDefaults standardUserDefaults] setObject: docID forKey: kPrefCurrentList];
}


// Returns the List object corresponding to a row in the table view.
- (List*) listForPath: (NSIndexPath*)indexPath {
    return [_dataSource documentAtIndexPath: indexPath].modelObject;
}


// Returns the index of the given list in the table view, or nil if not present.
- (NSIndexPath*) pathForList: (List*)list {
    return list ? [_dataSource indexPathForDocument: list.document] : nil;
}


// Selects a list in the table view, and displays it in the detail view
- (bool) selectList: (List*)list {
    [_tableView selectRowAtIndexPath: [self pathForList: list]
                            animated: NO
                      scrollPosition: UITableViewScrollPositionMiddle];
    [self showList: list];
    return true;
}


// Displays a list in the detail view (without changing the table selection)
- (void) showList: (List*)list {
    self.initialList = list;
    if (list) {
        if (!gRunningOnIPad) {
            if (!_listController)
                _listController = [[ListController alloc] initWithDatabase: _database];
            _listController.currentList = list;
            [self.navigationController pushViewController: _listController
                                                 animated: _initialLoadComplete];
        } else {
            _listController.currentList = list;
        }
    }
}


// Handles a command to create a new list, by displaying an alert to prompt for the title.
- (IBAction) newList: (id)sender {
    UIAlertView* alert= [[UIAlertView alloc] initWithTitle: @"New To-Do List"
                                                   message: @"Title for new list:"
                                                  delegate: self
                                         cancelButtonTitle: @"Cancel"
                                         otherButtonTitles: @"Create", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert show];
}

// Completion routine for the new-list alert.
- (void)alertView:(UIAlertView *)alert didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex > 0) {
        NSString* title = [alert textFieldAtIndex: 0].text;
        if (title.length > 0) {
            List* list = [self createListWithTitle: title];
            if (list)
                [self showList: list];
        }
    }
}

// Actually creates a new List given a title.
- (List*) createListWithTitle: (NSString*)title {
    List* list = [[List alloc] initInDatabase: _database withTitle: title];
    NSError* error;
    if (![list save: &error]) {
        [gAppDelegate showAlert: @"create a list" error: error fatal: NO];
        return nil;
    }
    return list;
}


// Handles button command to toggle edit mode for the table view.
- (IBAction) editLists: (id)sender {
    [self setEditing: !_tableView.editing];
}

// Sets the edit mode for the table (updating the corresponding button's state.)
- (void) setEditing:(BOOL)editing {
    [_tableView setEditing: editing animated: YES];

    UIBarButtonSystemItem item = editing ? UIBarButtonSystemItemDone : UIBarButtonSystemItemEdit;
    UIBarButtonItem* editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:item
                                                                                target:self
                                                                                action:@selector(editLists:)];
    self.navigationItem.rightBarButtonItem = editButton;
}


// Delegate method called when the live-query results change.
- (void)couchTableSource:(CBLUITableSource*)source
         updateFromQuery:(CBLLiveQuery*)query
            previousRows:(NSArray *)previousRows
{
    [_tableView reloadData];

    if (!_initialLoadComplete) {
        // On initial table load on launch, decide which row/list to select:
        [self selectList: self.initialList];
        _initialLoadComplete = YES;
    }
}


// Delegate method to set up a new table cell
- (void)couchTableSource:(CBLUITableSource*)source
             willUseCell:(UITableViewCell*)cell
                  forRow:(CBLQueryRow*)row
{
    // Add right-pointing triangle, and set selection style:
    if (!gRunningOnIPad) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }

    // Set the cell background:
    static UIColor* kBGColor;
    if (!kBGColor)
        kBGColor = [UIColor colorWithPatternImage: [UIImage imageNamed:@"item_background_master"]];
    cell.backgroundColor = kBGColor;

    // Set the cell font:
    UILabel* textLabel = cell.textLabel;
    textLabel.backgroundColor = [UIColor clearColor];
    textLabel.font = [UIFont fontWithName: @"MarkerFelt-Wide" size:24.0];
    textLabel.minimumScaleFactor = 0.75;
    textLabel.adjustsFontSizeToFitWidth = YES;
}


// Delegate method to handle a row selection
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CBLQueryRow *row = [self.dataSource rowAtIndex:indexPath.row];
    List* list = [List modelForDocument: row.document];

    [self showList: list];
}


@end
