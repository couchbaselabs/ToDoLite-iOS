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
    
    CBLLiveQuery *liveQuery = [Profile queryProfilesInDatabase:database].asLiveQuery;
    _dataSource.query = liveQuery;
    _dataSource.labelProperty = @"name";
    _dataSource.deletionAllowed = NO;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - TableView

@end
