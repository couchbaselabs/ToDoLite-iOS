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
    [self setup];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (!self.database) {
        [self setup];
    }
    
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    [app addObserver:self forKeyPath:@"database"
             options:(NSKeyValueObservingOptionNew |  NSKeyValueObservingOptionOld) context:nil];

    self.loginButton.title = [app isUserLoggedIn] ? @"Logout" : @"Login";

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
        CBLQueryRow *row = [self.dataSource rowAtIndex:indexPath.row];
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

- (IBAction)loginButtonAction:(id)sender {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    if ([app isUserLoggedIn]) {
        [app logout];
    } else {
        [app loginWithFacebook:^(BOOL success, NSError *error) {
            if (success) {
                self.loginButton.title = @"Logout";
            } else {
                [app showMessage:@"Facebook Login Error. Please try again." withTitle:@"Error"];
            }
        }];
    }
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

#pragma mark - Table View

- (void)couchTableSource:(CBLUITableSource *)source
         updateFromQuery:(CBLLiveQuery *)query previousRows:(NSArray *)previousRows {
    [self.tableView reloadData];
}

// Delegate method to set up a new table cell
- (void)couchTableSource:(CBLUITableSource*)source
             willUseCell:(UITableViewCell*)cell forRow:(CBLQueryRow*)row {
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self performSegueWithIdentifier:@"showDetail" sender:self];
}

- (bool)couchTableSource:(CBLUITableSource *)source deleteRow:(CBLQueryRow *)row {
    List *list = [List modelForDocument:row.document];
    return [list deleteList:nil];
}

#pragma mark - Observers

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    if (object == app && [keyPath isEqual:@"database"]) {
        [self setup];
    }
}

#pragma mark - Database

- (void)setup {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    self.database = app.database;
    
    if (self.database != nil) {
        _dataSource.query = [List queryListsInDatabase:self.database].asLiveQuery;
        _dataSource.labelProperty = @"title";
    } else {
        _dataSource.query = nil;
    }
    
    [self.tableView reloadData];
}

- (List *)createListWithTitle:(NSString*)title {
    List *list = [[List alloc] initInDatabase:self.database withTitle:title];
    
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    NSString *currentUserId = app.currentUserId;
    if (currentUserId) {
        Profile *owner = [Profile profileInDatabase:self.database forUserID:currentUserId];
        list.owner = owner;
    }
    
    NSError *error;
    if (![list save:&error]) {
        [app showMessage:@"Cannot create a new list" withTitle:@"Error"];
        return nil;
    }
    
    return list;
}

@end
