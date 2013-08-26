//
//  MasterController.m
//  CouchbaseLists
//
//  Created by Jens Alfke on 8/23/13.
//
//

#import "MasterController.h"
#import "AppDelegate.h"
#import "ListController.h"
#import "List.h"
#import <CouchbaseLite/CouchbaseLite.h>


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


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}


- (void) useDatabase:(CBLDatabase *)db {
    _database = db;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    NSAssert(_dataSource, @"_dataSource not connected");
    NSAssert(_database, @"db not connected");

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

    _query = [List queryListsInDatabase: _database].asLiveQuery;
    _dataSource.query = _query;
    _dataSource.labelProperty = @"title";    // Document property to display in the cell label
}


- (void)viewWillAppear:(BOOL)animated {
    NSLog(@"ViewWillAppear");//TEMP
    [super viewWillAppear: animated];
    if (!gRunningOnIPad) {
        if (_initialLoadComplete)
            self.initialList = nil;
    }
}


// Returns the list that was showing on quit:
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


- (void) setInitialList: (List*)list {
    //
    NSString* docID = list ? list.document.documentID : @"";
    [[NSUserDefaults standardUserDefaults] setObject: docID forKey: kPrefCurrentList];
}


- (List*) listForPath: (NSIndexPath*)indexPath {
    return [_dataSource documentAtIndexPath: indexPath].modelObject;
}


- (NSIndexPath*) pathForList: (List*)list {
    return list ? [_dataSource indexPathForDocument: list.document] : nil;
}


// Select a list in the table view, and display it in the detail view
- (bool) selectList: (List*)list {
    NSIndexPath* path = [self pathForList: list];
//    if (!path) {
//        return false;
    [_tableView selectRowAtIndexPath: path
                            animated: NO
                      scrollPosition: UITableViewScrollPositionMiddle];
    [self showList: list];
    return true;
}


// Display a list in the detail view (without changing the table selection)
- (void) showList: (List*)list {
    self.initialList = list;
    if (list) {
        if (!gRunningOnIPad) {
            if (!_listController) {
                _listController = [[ListController alloc] initWithNibName: @"ListController"
                                                                   bundle: nil];
                [_listController useDatabase: _database];
            }
            _listController.currentList = list;
            [self.navigationController pushViewController: _listController
                                                 animated: _initialLoadComplete];
        } else {
            _listController.currentList = list;
        }
    }
}


- (IBAction) newList: (id)sender {
    UIAlertView* alert= [[UIAlertView alloc] initWithTitle: @"New To-Do List"
                                                   message: @"Title for new list:"
                                                  delegate: self
                                         cancelButtonTitle: @"Cancel"
                                         otherButtonTitles: @"Create", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert show];
}

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

- (List*) createListWithTitle: (NSString*)title {
    List* list = [[List alloc] initInDatabase: _database withTitle: title];
    NSError* error;
    if (![list save: &error]) {
        [gAppDelegate showAlert: @"create a list" error: error fatal: NO];
        return nil;
    }
    return list;
}


- (IBAction) editLists: (id)sender {
    [self setEditing: !_tableView.editing];
}

- (void) setEditing:(BOOL)editing {
    [_tableView setEditing: editing animated: YES];

    UIBarButtonSystemItem item = editing ? UIBarButtonSystemItemDone : UIBarButtonSystemItemEdit;
    UIBarButtonItem* editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:item
                                                                                target:self
                                                                                action:@selector(editLists:)];
    self.navigationItem.rightBarButtonItem = editButton;
}


// Delegate method called when table contents change
- (void)couchTableSource:(CBLUITableSource*)source
         updateFromQuery:(CBLLiveQuery*)query
            previousRows:(NSArray *)previousRows
{
    [_tableView reloadData];

    if (!_initialLoadComplete) {
        // On initial table load, decide which row/list to select:
        [self selectList: self.initialList];
//        if (!gRunningOnIPad) {
//            [self showList: list];
//        }
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
