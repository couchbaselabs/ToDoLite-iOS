//
//  MasterViewController.m
//  TodoLite7
//
//  Created by Chris Anderson on 11/14/13.
//  Copyright (c) 2013 Chris Anderson. All rights reserved.
//

#import "AppDelegate.h"
#import "MasterViewController.h"
#import "DetailViewController.h"
#import "List.h"
#import "Profile.h"
#import <CouchbaseLite/CouchbaseLite.h>

@interface MasterViewController () {
    CBLDatabase *database;
    AppDelegate *app;
}
@end

@implementation MasterViewController

- (void)awakeFromNib {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.preferredContentSize = CGSizeMake(320.0, 600.0);
    }
    [super awakeFromNib];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	
    app = [[UIApplication sharedApplication] delegate];
    database = app.database;
    NSAssert(_dataSource, @"_dataSource not connected");
    _dataSource.query = [List queryListsInDatabase: database].asLiveQuery;
    _dataSource.labelProperty = @"title";    // Document property to display in the cell label
    
    if (!app.cblSync.userID) {
        UIBarButtonItem *loginButton = [[UIBarButtonItem alloc] initWithTitle:@"Login"
                                                                        style:UIBarButtonItemStylePlain
                                                                       target:self
                                                                       action:@selector(doLogin:)];
        self.navigationItem.leftBarButtonItem = loginButton;
    }
    
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                               target:self
                                                                               action:@selector(insertNewObject:)];
    self.navigationItem.rightBarButtonItem = addButton;
    self.detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Couchbase Lite Data

- (IBAction)doLogin:(id)sender {
    [app loginAndSync: ^(){
        NSLog(@"called complete loginAndSync");
    }];
}

// Handles a command to create a new list, by displaying an alert to prompt for the title.
- (IBAction) insertNewObject: (id)sender {
    UIAlertView* alert= [[UIAlertView alloc] initWithTitle:@"New To-Do List"
                                                   message:@"Title for new list:"
                                                  delegate:self
                                         cancelButtonTitle:@"Cancel"
                                         otherButtonTitles:@"Create", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert show];
}

// Completion routine for the new-list alert.
- (void)alertView:(UIAlertView *)alert didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex > 0) {
        NSString* title = [alert textFieldAtIndex: 0].text;
        if (title.length > 0) {
            List* list = [self createListWithTitle: title];
            if (list) {
                // [self showList: list];
            }
        }
    }
}

// Actually creates a new List given a title.
- (List *)createListWithTitle:(NSString*)title {
    List *list = [[List alloc] initInDatabase: database withTitle: title];
    if (app.cblSync.userID) {
        Profile *myUser = [Profile profileInDatabase: database forUserID:app.cblSync.userID];
        list.owner = myUser;
    }
    
    NSError* error;
    if (![list save: &error]) {
        UIAlertView* alert= [[UIAlertView alloc] initWithTitle:@"Error"
                                                       message:@"Cannot create a new list."
                                                      delegate:nil
                                             cancelButtonTitle:@"Ok"
                                             otherButtonTitles:nil];
        [alert show];
        return nil;
    }
    
    return list;
}


// Delegate method called when the live-query results change.
- (void)couchTableSource:(CBLUITableSource*)source
         updateFromQuery:(CBLLiveQuery*)query
            previousRows:(NSArray *)previousRows {
    [[self tableView] reloadData];
}


#pragma mark - Table View

// Delegate method to set up a new table cell
- (void)couchTableSource:(CBLUITableSource*)source
             willUseCell:(UITableViewCell*)cell
                  forRow:(CBLQueryRow*)row {
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}


//todo call this from the table view
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        CBLQueryRow *row = [self.dataSource rowAtIndex:indexPath.row];
        List* list = [List modelForDocument: row.document];
        self.detailViewController.detailItem = list;
    } else {
        [self performSegueWithIdentifier:@"showDetail" sender:self];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        CBLQueryRow *row = [self.dataSource rowAtIndex:indexPath.row];
        List* list = [List modelForDocument: row.document];
        [[segue destinationViewController] setDetailItem:list];
    }
}

@end
