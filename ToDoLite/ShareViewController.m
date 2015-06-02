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
    
    CBLLiveQuery *query = [[Profile queryProfilesInDatabase:database] asLiveQuery];
    self.dataSource.query = query;
    self.dataSource.labelProperty = @"name";
    self.dataSource.deletionAllowed = NO;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - TableView

- (NSString *)docIdForId:(NSString *)idStr {
    return [NSString stringWithFormat:@"p:%@", idStr];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CBLQueryRow *row = [self.dataSource rowAtIndexPath:indexPath];
    NSString *currentId = row.document.documentID;

    if ([currentId isEqualToString:[self docIdForId:app.currentUserId]]) {
        [tableView reloadData];
        return;
    }

    NSMutableArray *members = [NSMutableArray arrayWithArray:[self.list.document propertyForKey:@"members"]];
    if ([members containsObject:currentId]) {
        [members removeObject:currentId];
    } else {
        [members addObject:currentId];
    }
    self.list.members = members;

    [self.list save:nil];

    [tableView reloadData];
}

- (void)couchTableSource:(CBLUITableSource *)source willUseCell:(UITableViewCell *)cell forRow:(CBLQueryRow *)row {
    if ([row.documentID isEqualToString:[self docIdForId:app.currentUserId]]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        return;
    }

    if ([self.list.members containsObject:row.documentID]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
}

@end
