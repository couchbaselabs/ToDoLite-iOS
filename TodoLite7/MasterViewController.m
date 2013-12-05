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

- (void)awakeFromNib
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
//        self.clearsSelectionOnViewWillAppear = NO;
        self.preferredContentSize = CGSizeMake(320.0, 600.0);
    }
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(insertNewObject:)];
    self.navigationItem.rightBarButtonItem = addButton;
    self.detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    //    set data source to use query from List model
    app = [[UIApplication sharedApplication] delegate];
    database = app.database;
    NSAssert(_dataSource, @"_dataSource not connected");
    _dataSource.query = [List queryListsInDatabase: database].asLiveQuery;
    _dataSource.labelProperty = @"title";    // Document property to display in the cell label
    if (!app.cblSync.userID) {
        UIBarButtonItem *loginButton = [[UIBarButtonItem alloc] initWithTitle:@"Login" style:UIBarButtonItemStylePlain target:self action:@selector(doLogin:)];
        self.navigationItem.leftBarButtonItem = loginButton;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Couchbase Lite Data

- (IBAction) doLogin: (id)sender {
    self.navigationItem.leftBarButtonItem.enabled = NO;
    [app loginAndSync: ^(){
        NSLog(@"called complete loginAndSync");
    }];
}

// Handles a command to create a new list, by displaying an alert to prompt for the title.
- (IBAction) insertNewObject: (id)sender {
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

            if (list) {
//                [self showList: list];
            }
        }
    }
}

// Actually creates a new List given a title.
- (List*) createListWithTitle: (NSString*)title {
    List* list = [[List alloc] initInDatabase: database withTitle: title];
    
    if (app.cblSync.userID) {
        NSLog(@"list owner %@", app.cblSync.userID);
        Profile *myUser = [Profile profileInDatabase: database forUserID:app.cblSync.userID];
        list.owner = myUser;
    }
    
    NSError* error;
    
    if (![list save: &error]) {
//        [app showAlert: @"create a list" error: error fatal: NO];
        return nil;
    }
    return list;
}



// Delegate method called when the live-query results change.
- (void)couchTableSource:(CBLUITableSource*)source
         updateFromQuery:(CBLLiveQuery*)query
            previousRows:(NSArray *)previousRows
{
//    NSLog(@"couchTableSource previousRows %@",previousRows);

    [[self tableView] reloadData];
    
//    if (!_initialLoadComplete) {
//        // On initial table load on launch, decide which row/list to select:
//        [self selectList: self.initialList];
//        _initialLoadComplete = YES;
//    }
}


#pragma mark - Table View

// Delegate method to set up a new table cell
- (void)couchTableSource:(CBLUITableSource*)source
             willUseCell:(UITableViewCell*)cell
                  forRow:(CBLQueryRow*)row
{
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

//todo call this from the table view
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"didSelectRowAtIndexPath");

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
//        NSDate *object = _objects[indexPath.row];
        CBLQueryRow *row = [self.dataSource rowAtIndex:indexPath.row];
        List* list = [List modelForDocument: row.document];
        self.detailViewController.detailItem = list;
        NSLog(@"didSelectRowAtIndexPath list %@",list.description);

        
        //        [self showList: list];

    } else {
        [self performSegueWithIdentifier:@"showDetail" sender:self];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSLog(@"prepareForSegue: %@", segue.identifier);
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        CBLQueryRow *row = [self.dataSource rowAtIndex:indexPath.row];
        List* list = [List modelForDocument: row.document];
        NSLog(@"prepareForSegue list %@",list.description);
        [[segue destinationViewController] setDetailItem:list];
    }
}

@end
