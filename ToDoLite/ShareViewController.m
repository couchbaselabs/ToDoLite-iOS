//
//  ShareViewController.m
//  TodoLite7
//
//  Created by Chris Anderson on 11/14/13.
//  Copyright (c) 2013 Chris Anderson. All rights reserved.
//

#import "AppDelegate.h"
#import "ShareViewController.h"
#import "Profile.h"
#import "List.h"

@interface ShareViewController () {
    CBLDatabase *database;
    AppDelegate *app;
    NSString* myDocId;
}

@end

@implementation ShareViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    app = [[UIApplication sharedApplication] delegate];
    database = app.database;
    myDocId = [@"p:" stringByAppendingString:app.currentUserId];
    
    [self configureView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)configureView {
    _dataSource.query = [Profile queryProfilesInDatabase:database].asLiveQuery;
    _dataSource.labelProperty = @"name";    // Document property to display in the cell label
    _dataSource.deletionAllowed = NO;
}

#pragma mark - Properties

- (void)setList:(List *)newList {
    if (_list != newList) {
        _list = newList;
        [self configureView];
    }
}

#pragma mark - TableView

// Customizes the appearance of table view cells.
- (void)couchTableSource:(CBLUITableSource*)source willUseCell:(UITableViewCell*)cell forRow:(CBLQueryRow*)row {
    NSString *personId = row.document.documentID;

    // if the person's id is in the list of members, or is the owner we are happy.
    bool member = NO;
    if ([myDocId isEqualToString:personId]) {
        member = YES;
    } else {
        NSMutableSet *intersection = [NSMutableSet setWithArray:_list.members];
        [intersection intersectSet:[NSSet setWithObject:personId]];
        if ([intersection count] > 0) {
            member = YES;
        }
    }
    
    if (member) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CBLQueryRow *row = [self.dataSource rowAtIndex:indexPath.row];
    NSString *toggleMemberId = row.document.documentID;
    NSArray *members = _list.members;
    if (!members) members = @[];
    
    NSUInteger index = [members indexOfObject:toggleMemberId];
    if (index == NSNotFound) {
        _list.members = [members arrayByAddingObject:toggleMemberId];
    } else {
        _list.members = [members filteredArrayUsingPredicate:
                         [NSPredicate predicateWithFormat:@"SELF != %@" argumentArray:@[toggleMemberId]]];
    }
    NSLog(@"!!!!! %@", [_list.members componentsJoinedByString:@" "]);
    
    // Save changes:
    NSError* error;
    if (![_list save: &error]) {
    }
    [self configureView];
}

@end
