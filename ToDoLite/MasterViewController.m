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

#pragma mark - Shake

- (void)viewDidAppear:(BOOL)animated {
    [self becomeFirstResponder];
}

-(void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (motion == UIEventSubtypeMotionShake) {
        NSError *err;
        [[self.database createDocument] putProperties:@{ @"type": @"shake", @"event": event.debugDescription }
                                                error:&err];
    }
}

-(BOOL)canBecomeFirstResponder {
    return YES;
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
    return [self.listsResult count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"List" forIndexPath:indexPath];

    CBLQueryRow *row = [self.listsResult objectAtIndex:indexPath.row];
    cell.textLabel.text = [row.document propertyForKey:@"title"];

    return cell;
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
    self.listsResult = self.liveQuery.rows.allObjects;
    [self.tableView reloadData];
}

#pragma mark - Database

- (void)setupTodoLists {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    self.database = app.database;

    CBLQuery *query = [List queryListsInDatabase:self.database];
    self.liveQuery = [query asLiveQuery];
    [self.liveQuery addObserver:self forKeyPath:@"rows" options:0 context:nil];
}

- (List *)createListWithTitle:(NSString*)title {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    NSString *currentUserId = app.currentUserId;

    List *list = [List modelForNewDocumentInDatabase:self.database];
    list.title = title;
    list.owner = [Profile profileInDatabase:self.database forExistingUserId:currentUserId];

    NSError *error;
    [list save:&error];

    NSLog(@"List : %@", list.document.properties);

    return list;
}

@end
