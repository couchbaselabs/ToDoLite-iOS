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
#import "TaskTableViewCell.h"
#import "ImageViewController.h"

#define ImageDataContentType @"image/jpg"

@interface DetailViewController () {
    AppDelegate *app;
    Task *taskToAddImageTo;
    UIImage *imageForNewTask;
    UIPopoverController *imagePickerPopover;
}

@property (strong, nonatomic) UIPopoverController *masterPopoverController;

- (void)configureView;
- (BOOL)hasCamera;
- (void)displayAddImageActionSheetFor:(UIView *)sender forTask:(Task *)task;
- (void)displayImagePickerForSourceType:(UIImagePickerControllerSourceType)sourceType;
- (void)updateAddImageButtonWithImage:(UIImage *)image;
- (NSData *)dataForImage:(UIImage *)image;

@end

@implementation DetailViewController

#pragma mark - Managing the detail item

- (void)setDetailItem:(id)newDetailItem {
    if (_detailItem != newDetailItem) {
        _detailItem = newDetailItem;
        // Update the view.
        [self configureView];
    }

    if (self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }        
}

- (void)configureView {
    // Update the user interface for the detail item.
    if (self.detailItem) {
        self.title = self.detailItem.title;
        self.addImageButton.enabled = YES;
        self.addItemTextField.enabled = YES;
        
        if (YES) { // ([self.detailItem ownedByUser] || noUser)
            self.navigationItem.rightBarButtonItem.title = @"Share";
        } // else do "Info" button so members can see list membership

        NSAssert(_dataSource, @"detail _dataSource not connected");
        _dataSource.labelProperty = @"title"; // Document property to display in the cell label
        _dataSource.query = [[self.detailItem queryTasks] asLiveQuery];
    } else {
        self.title = nil;
        self.addImageButton.enabled = NO;
        self.addItemTextField.enabled = NO;
    }
}

- (IBAction)shareButtonAction:(id)sender {
    [app loginAndSync: ^(){
        [self performSegueWithIdentifier:@"setupSharing" sender:self];
    }];
}

- (BOOL)hasCamera {
    return [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
}

- (void)displayAddImageActionSheetFor:(UIView *)sender forTask:(Task *)task {
    taskToAddImageTo = task;
    
    UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
    
    if ([self hasCamera]) [actionSheet addButtonWithTitle:@"Take Photo"];
    [actionSheet addButtonWithTitle:@"Choose Existing"];
    if (imageForNewTask)[actionSheet addButtonWithTitle:@"Delete"];
    [actionSheet addButtonWithTitle:@"Cancel"];
    
    [actionSheet setCancelButtonIndex:actionSheet.numberOfButtons - 1];
    [actionSheet setDelegate:self];
    [actionSheet showFromRect:sender.frame inView:[sender superview] animated:YES];
}

- (void)displayImagePickerForSourceType:(UIImagePickerControllerSourceType)sourceType {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = sourceType;
    picker.allowsEditing = YES;
    picker.delegate = self;
    
    imagePickerPopover = nil;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad &&
        sourceType == UIImagePickerControllerSourceTypePhotoLibrary) {
        imagePickerPopover = [[UIPopoverController alloc] initWithContentViewController:picker];
        [imagePickerPopover presentPopoverFromRect:self.view.bounds
                                            inView:self.view
                          permittedArrowDirections:UIPopoverArrowDirectionAny
                                          animated:YES];
    } else {
        [self presentViewController:picker animated:YES completion:^{ }];
    }
}

- (void)updateAddImageButtonWithImage:(UIImage *)image {
    if (image) {
        [_addImageButton setImage:image forState:UIControlStateNormal];
    } else {
        [_addImageButton setImage:[UIImage imageNamed:@"Camera"] forState:UIControlStateNormal];
    }
}

- (NSData *)dataForImage:(UIImage *)image {
    return UIImageJPEGRepresentation(image, 0.5);
}

- (IBAction)addImageButtonAction:(UIButton *)sender {
    [self displayAddImageActionSheetFor:sender forTask:nil];
}

// Customizes the appearance of table view cells.
- (UITableViewCell *)couchTableSource:(CBLUITableSource *)source cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Task";
    
    TaskTableViewCell *cell = (TaskTableViewCell *)[self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[TaskTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    CBLQueryRow *row = [source rowAtIndex:indexPath.row];
    
    Task *task = [Task modelForDocument: row.document];
    cell.task = task;
    cell.delegate = self;
    
    return cell;
}

// Called when a row is selected/touched.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CBLQueryRow *row = [self.dataSource rowAtIndex:indexPath.row];
    Task *task = [Task modelForDocument:row.document];
    
    // Toggle the document's 'checked' property:
    task.checked = !task.checked;
    
    // Save changes:
    NSError *error;
    if (![task save:&error]) {
//        [gAppDelegate showAlert: @"Failed to update item" error: error fatal: NO];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    app = [[UIApplication sharedApplication] delegate];

    [self configureView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Text Field

// Called when the text field's Return key is tapped.
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    NSString *title = _addItemTextField.text;
    if (title.length == 0) {
        return NO;  // Nothing entered
    }
    [_addItemTextField setText:nil];
    
    // Create and save a new task:
    NSAssert(_detailItem, @"no current list");
    
    NSData *image = imageForNewTask ? [self dataForImage:imageForNewTask] : nil;
    Task *task = [_detailItem addTaskWithTitle:title withImage:image withImageContentType:ImageDataContentType];
    NSError *error;
    if ([task save:&error]) {
        imageForNewTask = nil;
        [self updateAddImageButtonWithImage:nil];
    } else {
        // [AppDelegate showAlert: @"Couldn't save new item" error: error fatal: NO];
    }
    
	return YES;
}

#pragma mark - ActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        return;
    }
    
    if (imageForNewTask && buttonIndex == actionSheet.cancelButtonIndex - 1) {
        [self updateAddImageButtonWithImage:nil];
        imageForNewTask = nil;
        return;
    }
    
    UIImagePickerControllerSourceType sourceType = ([self hasCamera] && buttonIndex == 0) ?
        UIImagePickerControllerSourceTypeCamera : UIImagePickerControllerSourceTypePhotoLibrary;
    [self displayImagePickerForSourceType:sourceType];
}

#pragma mark - UIImagePickerViewDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *selectedImage = (UIImage *) [info objectForKey:UIImagePickerControllerEditedImage];
    if (taskToAddImageTo) {
        [taskToAddImageTo setImage:[self dataForImage:selectedImage] contentType:ImageDataContentType];
        
        NSError *error;
        if (![taskToAddImageTo save:&error]) {
            //TODO: Show an error dialog
        }
    } else {
        // new task
        imageForNewTask = selectedImage;
        [self updateAddImageButtonWithImage:imageForNewTask];
    }
    
    if (imagePickerPopover) {
        [imagePickerPopover dismissPopoverAnimated:YES];
    } else {
        [picker.presentingViewController dismissViewControllerAnimated:YES completion:^{ }];
    }
}

#pragma mark - TaskTableViewCellDelegate

- (void)didSelectImageButton:(UIButton *)imageButton ofTask:(Task *)task {
    CBLAttachment *attachment = [task attachmentNamed:@"image"];
    if (attachment) {
        ImageViewController *imageViewController =
            (ImageViewController *)[self.storyboard instantiateViewControllerWithIdentifier:@"ImageViewController"];
        imageViewController.image = [UIImage imageWithData:attachment.content];
        imageViewController.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:imageViewController animated:NO completion:^{ }];
    } else {
        [self displayAddImageActionSheetFor:imageButton forTask:task];
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self.addItemTextField resignFirstResponder];
}

#pragma mark - Split view

- (void)splitViewController:(UISplitViewController *)splitController
     willHideViewController:(UIViewController *)viewController
          withBarButtonItem:(UIBarButtonItem *)barButtonItem
       forPopoverController:(UIPopoverController *)popoverController {
    barButtonItem.title = NSLocalizedString(@"Todo Lists", @"Todo Lists");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController
     willShowViewController:(UIViewController *)viewController
  invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem {
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"setupSharing"]) {
        [(ShareViewController *)[segue destinationViewController] setList:_detailItem];
    }
}

@end
