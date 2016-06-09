//
//  ImageViewController.m
//  ToDoLite
//
//  Created by Pasin Suriyentrakorn on 4/8/14.
//  Copyright (c) 2014 Chris Anderson. All rights reserved.
//

#import "ImageViewController.h"

@interface ImageViewController ()

@end

@implementation ImageViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.imageView addGestureRecognizer:
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)]];
    [self.imageView setImage:self.image];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

#pragma mark - Properties

- (void)setImage:(UIImage *)image {
    _image = image;
    [self.imageView setImage:image];
}

#pragma mark - Gesture Recognizer

- (void)handleTap:(UIGestureRecognizer *)recognizer {
    [self dismissViewControllerAnimated:NO completion:^{ }];
}

@end
