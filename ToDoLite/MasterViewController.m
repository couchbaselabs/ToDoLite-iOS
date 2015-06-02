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

static void *listsQueryContext = &listsQueryContext;

@interface MasterViewController ()

@property CBLDatabase *database;
@property CBLLiveQuery *liveQuery;
@property NSArray *listsResult;

@end

@implementation MasterViewController

- (void)awakeFromNib {
    [super awakeFromNib];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.preferredContentSize = CGSizeMake(320.0, 600.0);
    }
    
    // There is a bug in iOS8 UISplitViewController on iPads that doesn't set the main button item
    // correctly during its first display. A work would be manually setting the master
    // controller title here.
    self.title = @"ToDo Lists";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupTodoLists];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (!self.database) {
        [self setupTodoLists];
    }
    
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    [app addObserver:self forKeyPath:@"database"
             options:(NSKeyValueObservingOptionNew |  NSKeyValueObservingOptionOld) context:nil];



    NSIndexPath *selected = [self.tableView indexPathForSelectedRow];
    if (selected) {
        [self.tableView deselectRowAtIndexPath:selected animated:NO];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    [app removeObserver:self forKeyPath:@"database" context:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        CBLQueryRow *row = [self.listsResult objectAtIndex:indexPath.row];
        List *list = [List modelForDocument:row.document];
        
        DetailViewController *controller;
        if ([[segue destinationViewController] isKindOfClass:[UINavigationController class]]) {
            controller = (DetailViewController *)[[segue destinationViewController] topViewController];
        } else {
            controller = [segue destinationViewController];
        }
        
        if ([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] != NSOrderedAscending) {
            controller.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
            controller.navigationItem.leftItemsSupplementBackButton = YES;
        } else {
            // For iOS7, Setting the display mode is done in DetailViewController.setList: method.
        }
        
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
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
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
    self.listsResult = self.liveQuery.rows.allObjects;
    [self.tableView reloadData];
}

#pragma mark - Database

// In this View Controller, we show an example of a Live Query
// and KVO to update the Table View accordingly when data changed.
// See DetailViewController and ShareViewController for
// examples of a Live Query used with the CBLUITableSource api.
- (void)setupTodoLists {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    self.database = app.database;
    
    
}

- (List *)createListWithTitle:(NSString*)title {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    NSString *currentUserId = app.currentUserId;
    
    
    List *list = [List modelForNewDocumentInDatabase:self.database];
    list.title = title;
    if (currentUserId) {
        Profile *owner = [Profile profileInDatabase:self.database forExistingUserId:currentUserId];
        list.owner = owner;
    }
    
    [list save:nil];
    NSLog(@"The list was saved %@", [[list document] properties]);
    
    return list;
}

@end
