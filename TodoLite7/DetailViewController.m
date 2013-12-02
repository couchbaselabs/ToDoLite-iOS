//
//  DetailViewController.m
//  TodoLite7
//
//  Created by Chris Anderson on 11/14/13.
//  Copyright (c) 2013 Chris Anderson. All rights reserved.
//

#import "DetailViewController.h"
#import "AppDelegate.h"
#import "Task.h"
#import "Profile.h"
#import "ShareViewController.h"

@interface DetailViewController ()
@property (strong, nonatomic) UIPopoverController *masterPopoverController;
- (void)configureView;
@end

@implementation DetailViewController{
    AppDelegate *app;
}

#pragma mark - Managing the detail item

- (void)setDetailItem:(id)newDetailItem
{
    if (_detailItem != newDetailItem) {
        _detailItem = newDetailItem;
        // Update the view.
        [self configureView];
    }

    if (self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }        
}

- (void)configureView
{
    // Update the user interface for the detail item.
    if (self.detailItem) {
        self.title = self.detailItem.title;
        if (TRUE) { // ([self.detailItem ownedByUser] || noUser)
            self.navigationItem.rightBarButtonItem.title = @"Share";
        } // else do "Info" button so members can see list membership

        NSAssert(_dataSource, @"detail _dataSource not connected");
        _dataSource.labelProperty = @"title";    // Document property to display in the cell label
        _dataSource.query = [[self.detailItem queryTasks] asLiveQuery];
    }
}

- (IBAction) shareButtonAction:(id)sender {
    NSLog(@"Setup Sharing");
    [app loginAndSync: ^(){
//            if it works, then
        [self performSegueWithIdentifier:@"setupSharing" sender:self];
    }];
}




// Customizes the appearance of table view cells.
- (void)couchTableSource:(CBLUITableSource*)source
             willUseCell:(UITableViewCell*)cell
                  forRow:(CBLQueryRow*)row
{

    
    // Configure the cell contents.
    // (cell.textLabel.text is already set, thanks to setting up labelProperty above.)
    Task* task = [Task modelForDocument: row.document];
    bool checked = task.checked;
    cell.textLabel.textColor = checked ? [UIColor grayColor] : [UIColor blackColor];
    if (checked) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
}

// Called when a row is selected/touched.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CBLQueryRow *row = [self.dataSource rowAtIndex:indexPath.row];
    Task* task = [Task modelForDocument: row.document];
    
    // Toggle the document's 'checked' property:
    task.checked = !task.checked;
    
    // Save changes:
    NSError* error;
    if (![task save: &error]) {
//        [gAppDelegate showAlert: @"Failed to update item" error: error fatal: NO];
    }
}


- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    app = [[UIApplication sharedApplication] delegate];

    [self configureView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - TEXT FIELD

// Called when the text field's Return key is tapped.
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
//	[textField resignFirstResponder];
    NSString *title = _addItemTextField.text;
    if (title.length == 0) {
        return NO;  // Nothing entered
    }
    [_addItemTextField setText:nil];
    
    // Create and save a new task:
    NSAssert(_detailItem, @"no current list");
    Task* task = [_detailItem addTaskWithTitle: title];
    NSError* error;
    if (![task save: &error]) {
        //        [gAppDelegate showAlert: @"Couldn't save new item" error: error fatal: NO];
    }
	return YES;
}

#pragma mark - Split view

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = NSLocalizedString(@"Todo Lists", @"Todo Lists");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSLog(@"prepareForSegue: %@", segue.identifier);
    if ([[segue identifier] isEqualToString:@"setupSharing"]) {
//        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
//        CBLQueryRow *row = [self.dataSource rowAtIndex:indexPath.row];
//        List* list = [List modelForDocument: row.document];
//        NSLog(@"prepareForSegue list %@",list.description);
        [(ShareViewController*)[segue destinationViewController] setList:_detailItem];
    }
}

@end
