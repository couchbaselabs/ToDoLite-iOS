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
    
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)couchTableSource:(CBLUITableSource * __nonnull)source willUseCell:(UITableViewCell * __nonnull)cell forRow:(CBLQueryRow * __nonnull)row {
    
}

#pragma mark - TableView

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
}

@end
