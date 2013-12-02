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

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)setList:(List *)newList
{
    if (_list != newList) {
        _list = newList;
        // Update the view.
        [self configureView];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    app = [[UIApplication sharedApplication] delegate];
    database = app.database;
    myDocId = [@"p:" stringByAppendingString:app.cblSync.userID];

    [self configureView];
}

- (void)configureView
{
	// Do any additional setup after loading the view.
    _dataSource.query = [Profile queryProfilesInDatabase: database].asLiveQuery;
    _dataSource.labelProperty = @"name";    // Document property to display in the cell label}
}

// Customizes the appearance of table view cells.
- (void)couchTableSource:(CBLUITableSource*)source
             willUseCell:(UITableViewCell*)cell
                  forRow:(CBLQueryRow*)row
{
    
    // Configure the cell contents.
    // (cell.textLabel.text is already set, thanks to setting up labelProperty above.)
    NSString* personId = row.document.documentID;
//    if the person's id is in the list of members, or is the owner we are happy.
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
    NSArray *ms = _list.members;
    if (!ms) ms = @[];

    NSLog(@"toggle %@ members %@", toggleMemberId, [ms componentsJoinedByString:@" "]);

    NSUInteger x = [ms indexOfObject:toggleMemberId];
    NSLog(@"index member %d",x);
    
    if (x == NSNotFound) {
//        add to array
        _list.members = [ms arrayByAddingObject:toggleMemberId];
    } else {
//        remove from array
        _list.members = [ms filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF != %@" argumentArray:@[toggleMemberId]]];
    }
    NSLog(@"!!!!! %@", [_list.members componentsJoinedByString:@" "]);
    
    // Save changes:
    NSError* error;
    if (![_list save: &error]) {
    }
    [self configureView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
