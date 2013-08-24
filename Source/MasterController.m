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


@interface MasterController () <UIAlertViewDelegate>
@end


@implementation MasterController
{
    CBLDatabase* _database;
    CBLLiveQuery* _query;
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

    // Create an initial list if the db is empty:
    CBLQuery* query = [List queryListsInDatabase: _database];
    if (query.rows.nextRow == nil) {
        NSLog(@"No lists found; creating initial one");
        [self createListWithTitle: @"To Do"];
    }
    _query = query.asLiveQuery;
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

    _dataSource.labelProperty = @"title";    // Document property to display in the cell label
    _dataSource.query = _query;
}


- (List*) listForPath: (NSIndexPath*)indexPath {
    return [_dataSource documentAtIndexPath: indexPath].modelObject;
}


- (NSIndexPath*) pathForList: (List*)list {
    return [_dataSource indexPathForDocument: list.document];
}


- (bool) selectList: (List*)list {
    NSIndexPath* path = [self pathForList: list];
    if (!path)
        return false;
    [_tableView selectRowAtIndexPath: path
                            animated: NO
                      scrollPosition: UITableViewScrollPositionMiddle];
    [self showList: list];
    return true;
}


- (void) showList: (List*)list {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
	    if (!_listController) {
	        _listController = [[ListController alloc] initWithNibName:@"ListController"
                                                                   bundle:nil];
            [_listController useDatabase: _database];
        }
        _listController.currentList = list;
        [self.navigationController pushViewController: _listController animated: YES];
    } else {
        if (list != _listController.currentList)
            _listController.currentList = list;
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


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CBLQueryRow *row = [self.dataSource rowAtIndex:indexPath.row];
    List* list = [List modelForDocument: row.document];

    [self showList: list];
}


@end
