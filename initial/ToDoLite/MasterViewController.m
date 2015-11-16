//
//  MasterViewController.m
//  ToDoLite
//
//  Created by Pasin Suriyentrakorn on 10/11/14.
//  Copyright (c) 2014 Pasin Suriyentrakorn. All rights reserved.
//

#import "MasterViewController.h"
#import "DetailViewController.h"
#import "AppDelegate.h"
#import "Profile.h"
#import "List.h"

@interface MasterViewController ()

@property CBLDatabase *database;
@property CBLLiveQuery *liveQuery;
@property NSArray *listsResult;

@end

@implementation MasterViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupTodoLists];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        CBLQueryRow *row = [self.listsResult objectAtIndex:indexPath.row];
        List *list = [List modelForDocument:row.document];
        
        DetailViewController *controller = [segue destinationViewController];
        controller.list = list;
    }
}

#pragma mark - Buttons

- (IBAction)addButtonAction:(id)sender {
    UIAlertView* alert= [[UIAlertView alloc] initWithTitle:@"New ToDo List"
                                                   message:@"Title for new list:"
                                                  delegate:self
                                         cancelButtonTitle:@"Cancel"
                                         otherButtonTitles:@"Create", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert show];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alert didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex > 0) {
        NSString* title = [alert textFieldAtIndex:0].text;
        if (title.length > 0) {
            [self createListWithTitle:title];
        }
    }
}

#pragma mark - Table View Datasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Step 5: return the listsResult count from here
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Step 5: dequeue a table cell view for the list, create a CBLQueryRow and set the label text from the title of the row
    return nil;
}

#pragma mark - Table View Delegate

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        CBLQueryRow* row = [self.listsResult objectAtIndex:indexPath.row];
        List *list = [List modelForDocument:row.document];
        [list deleteList:nil];
    }
}

#pragma mark - Observers

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    // STEP 5: set the listsResult  to the live query and have the tableView reloadData
}

#pragma mark - Database

- (void)setupTodoLists {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    self.database = app.database;
    // Step 4: query the view, iterate and log the results
    // Step 5: remove the iteration/logging and set self.liveQuery to the query results, add an observer
}

- (List *)createListWithTitle:(NSString*)title {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    NSString *currentUserId = app.currentUserId;
    // Step 2: create a new List for the `title` with the list owner from the properties, log and return it
    return nil;
}

@end
